# Reading Plan Read Models

- Date: 2026-11-23
- Revised: 2026-11-24
- Status: Draft
- Related: [Reading Plan Repositories](reading-plan-repositories.md),
  [Reading Plan Service Refactor](reading-plan-service-refactor.md),
  [Four-Layer Architecture](../decisions/2026-11-18-four-layer-architecture.md),
  [Reactivity Patterns](../decisions/2026-11-18-reactivity-patterns.md),
  [Vertical Slices](../decisions/2026-11-19-vertical-slices.md)

# Context

The reading-plan view models currently consume a small number of large,
partially populated service results. The same facts are read through several
paths with slightly different shapes and semantics. That makes it hard to see
which facts belong together, which query should be reused, and which copy of a
number is authoritative.

This document inventories the current reads, identifies the near-overlaps, and
proposes a minimum set of read models derived from what the view models
actually use. Unlike the first draft, the read models do not live behind
service query methods: they are owned by a dedicated read-model container on
the reading-plan database. Services become command-only. View models read
from the container and refetch the state they need after commands.

The `reading-plan-read-models` herdr worktree (branch
`reading-plan-read-models`, up to commit `63f9a63`) is a reference
implementation of this direction; see [Reference implementation](#reference-implementation).

# Current source tables

| Table | Facts | Changed by |
|---|---|---|
| `reading_plan` | id, name, created_at, last_read (unused), collection_id, goal_type, goal_value, is_bookmarked | save, bookmark |
| `reading_plan_book` | ordered book membership | save, reorder, delete |
| `rs_verse_state` | per-verse cumulative `read_count` and `last_read`, one row per plan/book/chapter/verse | verse mark/unmark, materialization, restore |
| `rs_session` | one sitting: date, start/end, foreground `read_seconds`, `verses` | start, heartbeat, mark/unmark, end, rollover, manual add/delete |
| `rs_log` | per-verse read event tied to a session | verse mark/unmark, restore |
| `rs_day_summary` | per plan/local-day totals plus goal snapshot and `goal_reached` | heartbeat, mark/unmark, end, rollover |

Two facts are derived outside the database:

- expected chapter/verse counts come from the verse inventory
  (`VerseInventoryProvider`, backed by the Hebrew/Greek database);
- collections and book names come from static `BibleCollections` data.

# Current view-model inventory

## `ReadingPlanPanelViewModel`

Reads:

| Read | Underlying tables | What the panel uses |
|---|---|---|
| `getReadingPlansWithProgress()` | `reading_plan`, `reading_plan_book`, `rs_verse_state`, `rs_day_summary`, `rs_log` | the list |
| `deleteReadingPlan()` | all six tables | command |
| `ReadingSessionViewModel.startSession()` | session/log/summary | command |

`getReadingPlansWithProgress()` itself performs:

1. `getReadingPlans()` — all plans, then one `reading_plan_book` query per
   plan (N+1).
2. `getReadingPlanProgress()` — one aggregate over
   `reading_plan_book LEFT JOIN rs_verse_state` for all plans.
3. `getDaySummariesForDate(today)` — all plans' summaries for today.
4. `getResumeReference(planId)` — once per plan (N more reads): latest
   `rs_log` row joined to plan order, then the next `rs_verse_state` row.

Data needed by the card:

- plan id, name, bookmark flag;
- daily goal type and value;
- `totalVerses` and `versesRead` for the whole plan;
- today's `verses`, `minutes`, `goalReached`;
- resume position, with a fallback to the first plan book (or Genesis).

Change triggers: plan save/delete/bookmark/reorder (definition), verse
mark/unmark (progress and today), heartbeat (today).

## `ReadingPlanDetailViewModel`

Reads:

| Read | Underlying tables | What the detail uses |
|---|---|---|
| `getReadingPlanById(planId)` | `reading_plan`, `reading_plan_book`, `rs_log`, `rs_verse_state` | name, bookmark, ordered books, resume |
| `getBooksStats(planId)` | `reading_plan_book`, `rs_verse_state` | per-book totals/read/complete |
| `getDayProgress(planId, now)` | `rs_day_summary` | today's card |
| `getMonthProgress(planId, visibleMonth)` | `rs_day_summary` | calendar |
| `setReadingPlanBookmark()` | `reading_plan` | command |
| `ReadingSessionViewModel.startSession()` | session/log/summary | command |

Data needed by the detail screen:

- plan name, bookmark state, ordered books;
- per-plan-book total and read counts (for the book rows and completion);
- plan-wide `totalVerses`, `versesRead`, `booksRead`, overall fraction;
- current goal type/value (for today's goal and for the month fractions);
- today's verses, minutes, stored `goalReached`, fraction toward today's goal;
- each day in the visible month: whether it has a summary, stored
  `goalReached`, minutes/verses for the fraction and for opening the day log;
- remaining verses and daily goal, for the completion estimate;
- resume reference, with no-resume fallbacks;
- whether the plan has started.

Change triggers: same as the panel, plus month navigation.

## `DayActivityLogViewModel`

Reads:

| Read | Underlying tables | What the log uses |
|---|---|---|
| `getDetailedProgressFor(date, planId)` | `rs_session`, `rs_log` | one day's sessions |

Commands: `addManualSession()`, `deleteManualSession()`, each followed by a
refetch of the same day.

`getDetailedProgressFor()` performs one session query and then one log query
per session (N+1). It folds consecutive verse numbers in the same
book/chapter into ranges.

Data needed:

- per session: id, start time, `readSeconds`, `verses`;
- per session: ordered contiguous verse ranges (book/chapter/from/to);
- totals across sessions: seconds (shown as minutes) and verses.

It does not need the plan goal, plan name, or day summary.

## `EditReadingPlanViewModel`

Reads:

- a `ReadingPlanDetails` object passed in by the panel/detail view model;
- `BibleNavigation` counts for the unsaved-estimate calculation.

It does not query the database for the plan. The object it receives is not a
purpose-built edit model: it may be the list result, the detail result, or a
synthetic default plan, and it carries progress fields the editor never uses.

Data actually needed:

- existing plan id (or null for a new plan);
- plan name;
- goal type/value;
- ordered book ids;
- expected verse counts for the estimate (from the inventory, not the plan).

The editor never uses the plan's bookmark, created date, or progress.

Commands: save and delete.

## `EditBookListViewModel`

No service or database reads. It receives the initial ordered book ids from
the edit view model and uses static `BibleCollections` data for the available
book list.

## `ReadingSessionViewModel` (same slice, different service)

Reads through `ReadingSessionService`:

| Read | Underlying tables | Use |
|---|---|---|
| plan + books | `reading_plan`, `reading_plan_book` | build `ReadingPlanConfig` |
| `BibleNavigation` counts | Hebrew/Greek database | config totals |
| `getResumeReference()` | `rs_log`, `reading_plan_book`, `rs_verse_state` | start navigation |
| session row | `rs_session` | session id/day/start/read seconds |
| day summary | `rs_day_summary` | stored goal-reached flag |
| session totals for date | `rs_session` | today's verses and seconds |
| verse states for chapter | `rs_verse_state`, `rs_log` | checkboxes |
| verse count, book completion | `rs_verse_state` | completion event |
| per-verse log | `rs_log` | mark/unmark decision |

Data needed by the session UI:

- immutable plan config: goal and ordered book ids (the current
  `ReadingPlanConfig` also carries `planName`, `totalChapters`, and
  `totalVerses`, but no session consumer uses them);
- session runtime: session id/day/start time, foreground seconds for this
  session;
- today: verses, seconds, whether the stored daily goal was already reached;
- per-chapter verse state: total read count and "read in this session";
- completion event and next resume position.

Notable: `setVerseRead()` re-reads the full plan and rebuilds
`ReadingPlanConfig` on every verse toggle, although plan definition changes do
not change with verse state.

# Target ownership

Reads and writes are separated by owner:

- A read-model container (`ReadingPlanReadModels`) lives on the
  reading-plan database alongside the repositories. It exposes immutable
  facts and query methods. View models read from it directly.
- Services keep the business rules for **commands** only: save/delete,
  bookmark, reorder, session start/end/heartbeat/rollover, verse
  mark/unmark, manual session add/delete. Commands return ids and events,
  not screen-shaped state. After a command, the view model refetches the
  read models it needs.
- The container declares its cross-database need (expected verse totals) as
  the existing `VerseInventoryProvider` parameter; whoever constructs the
  database supplies it.

This is a deliberate deviation from the four-layer rule that view models
call only services, for this slice's reads. It needs a decision record and an
`ARCHITECTURE.md` update when the migration lands (see the migration plan),
because a future reader will ask why the read path skips the service layer.

# The minimum read-model set

Derived strictly from the usage inventory above. Each shape is immutable,
has one source, and is composed by view models rather than trying to be a
whole screen.

| Read model | Facts | Source tables | Used by |
|---|---|---|---|
| `ReadingPlanConfig` | plan id, name, bookmark, normalized daily goal, ordered books | `reading_plan`, `reading_plan_book` | edit (existing draft); panel/detail/session via summary |
| `ReadingPlanProgress` (+ `BookProgress`) | per-book verses read and denominator, `booksRead`, `isComplete`, resume position | `reading_plan_book`, `rs_verse_state`, `rs_log` | panel, detail, session start (via summary) |
| `DailyProgress` | one plan/day: seconds, verses, stored `goalReached`, stored goal snapshot | `rs_day_summary` | panel today, detail today, session today (via runtime) |
| month range of `DailyProgress` | sparse days of a visible month | `rs_day_summary` | detail calendar |
| `DayActivity` (+ `SessionActivity`, `VerseRange`) | one day's sessions with folded verse ranges | `rs_session`, `rs_log` | day activity log |
| `SessionRuntime` | session id/day/start/foreground seconds, plus today's `DailyProgress` | `rs_session`, `rs_day_summary` | session |
| `VerseReadState` map | per verse of a chapter: cumulative read count, read-this-session flag | `rs_verse_state`, `rs_log` | session checkboxes |

`ReadingPlanSummary` composes config + progress + today and adds the
`resumeTarget` fallback helper. It is not a source of truth; it exists because
three screens (panel, detail, session start) want exactly that composition, so
the container batches it into one read.

## Query surface

```dart
// ReadingPlanReadModels (on the reading-plan database)
Future<List<ReadingPlanSummary>> getPlanSummaries();
Future<ReadingPlanSummary?> getPlanSummary(int planId);
Future<ReadingPlanConfig?> getPlanConfig(int planId);
Future<Map<int, DailyProgress>> getMonthDayProgress(
  int planId,
  DateTime month,
); // sparse; key is day-of-month
Future<DayActivity> getDayActivity(int planId, DateTime day);
Future<SessionRuntime?> getSessionRuntime(int sessionId);
Future<Map<int, VerseReadState>> getVerseReadStates(
  int sessionId,
  int bookId,
  int chapter,
);
```

## Command surface (services)

Commands return ids and events only; the caller refetches:

```dart
// ReadingPlanService
Future<int> saveReadingPlan(...);
Future<void> deleteReadingPlan(int planId);
Future<void> setReadingPlanBookmark(int planId, bool value);
Future<void> addManualSession(...);
Future<void> deleteManualSession(int sessionId);

// ReadingSessionService
Future<int?> startSession(int planId); // session id
Future<void> endSession(int sessionId, ...);
Future<SetVerseReadResult?> setVerseRead(...); // verse states + book-completed event
Future<void> heartbeat(int sessionId, ...);
Future<int?> rolloverSession(...); // new session id
```

`ActiveSessionSnapshot`, `SessionProgress`, `ReadingPlanDetails` progress
fields, and `DetailedProgess` disappear from the service surface as each
migration step lands.

## Access pattern per view model

| View model | Reads | Notes |
|---|---|---|
| `ReadingPlanPanelViewModel` | `getPlanSummaries()` | one batched list read; no per-plan resume loop |
| `ReadingPlanDetailViewModel` | `getPlanSummary(planId)`, `getMonthDayProgress(planId, visibleMonth)` | derive today from the month range when the visible month contains today |
| `DayActivityLogViewModel` | `getDayActivity(planId, day)` | refetch after manual session add/delete; no N+1 log reads |
| `EditReadingPlanViewModel` | `getPlanConfig(planId)` or a synthetic draft | no progress fields, no fat `ReadingPlanDetails` |
| `EditBookListViewModel` | none | receives ordered ids from the edit view model |
| `ReadingSessionViewModel` | `getPlanSummary(planId)` at start, then `getSessionRuntime(sessionId)` and `getVerseReadStates(...)` | config is read once per session; runtime refetched after commands |

# Reference implementation

The `reading-plan-read-models` worktree already follows this direction: a
`ReadingPlanReadModels` container on `ReadingSessionDatabase`, view models
holding the container for reads, services reduced to commands with minimal
returns, and batched queries replacing the N+1 loops. Its query set matches
the table above almost exactly. Port it, correcting these deviations:

1. **Dense month reads.** Its `getMonthProgress` pads the month with
   `DayProgress.empty`. Use the sparse `Map<int, DailyProgress>` read plus
   `hasActivity` (see the empty/zero edge case below).
2. **Row-model leak.** Its `SessionDetails` exposes the `RsSession` row
   model, and the day-log view model re-derives totals and re-sorts ranges the
   read model already folded. Build a purpose-built `SessionActivity`.
3. **Raw goal snapshot.** Its `DayProgress` carries `goalType`/`goalValue`
   as raw stored strings. Normalize once at the read boundary into a
   `DailyGoal`.
4. **Materialized denominators.** Its `BookProgress.totalVerses` counts
   `rs_verse_state` rows, which is exactly the "100% for an incomplete plan"
   hazard. Decide denominators before porting (see open questions;
   recommendation: expected totals via `VerseInventoryProvider`).
5. **`collectionId`.** Its config carries `collection_id`, which the
   `remove-collection-id` branch deletes. Drop the field when that lands;
   the editor derives the collection from the book list.
6. **`getVerseReadCounts`.** Exposed on the container but used only by
   tests. Keep verse-count reads internal to the repositories unless a view
   model needs them.
7. **Inventory wiring.** The database's default constructor reaches into
   `getIt` for `HebrewGreekDatabase`, importing the other slice. Keep the
   declared `VerseInventoryProvider` parameter and move the default wiring to
   the service locator.

# Where things are close but not overlapping

| Pair | Overlap | Difference / risk |
|---|---|---|
| `getReadingPlanProgress` vs `getBookStats` | both aggregate `reading_plan_book` + `rs_verse_state` | grouped by plan vs by book; one returns last-read and a per-book "first unread" resume; two implementations of the same counts |
| `ReadingPlanDetails.totalVerses` vs `ReadingPlanConfig.totalVerses` | same name and UI role | list/detail fill it from materialized verse state; edit and session derive it from the verse inventory; missing verse state makes them disagree |
| `ReadingPlanDetails.resumePosition` vs `RsBookStats.resumePosition` | both called "resume" | plan resume is "next verse after the latest log, in plan order"; book resume is "first unread verse in this book"; the latter is unused by the detail view model |
| `getDayProgress` vs `getMonthProgress` | both read `rs_day_summary` | one-day read vs range read; today's day can be loaded by both with different freshness |
| `SessionProgress` vs `DailyProgress` | verses/seconds/goal-reached for today | session reads totals from `rs_session` and the flag from `rs_day_summary`; other screens read the summary; two sources for the same daily facts |
| `ReadingPlanDetails.dailyGoal` vs `ReadingPlanConfig.dailyGoal` | parse the plan's goal | same heuristic implemented in two models; one is mutable, one immutable |
| `DayProgress.goalReached` vs current plan goal | both drive the calendar fraction | `goalReached` is a stored snapshot, but the fraction is computed with the current plan goal, so a goal edit recolors history |
| `ReadingPlanDetails.empty` vs a zero-activity summary | both look like "no reading" | `empty` means "no row"; a written summary with zero seconds/verses is non-empty but has no activity, so some zero days are tappable and some are not |
| `rs_session.verses` vs `rs_day_summary.rs_verses` vs `rs_log` | all answer "how many verses today" | summary is derived from sessions, session count from mark/unmark commands, log is the domain source of truth; they can diverge after interrupted/legacy writes |
| `ReadingPlan.lastRead` vs `RsBookStats.lastRead` | both are "last read" timestamps | plan column is never updated; book value is computed and currently unused by the detail UI |
| `getReadingPlanById` vs config + progress reads | both load plan identity | the current method returns identity + books + resume, but not the progress its name implies; callers cannot tell what is loaded |
| `ReadingPlanDetails.books.length` vs `collectionBookCount` | both describe plan size | book list is the source of truth; collection is derived by matching, while the editor also has a stored `collectionId` |

# Edge cases that make access patterns hard to identify

## Resume has two incompatible meanings

`getResumeReference` returns the next verse after the most recent log, in plan
order, even if that verse was already read. `getBookStats` returns the first
unread verse in a book. Only the first is used by the UI. Name them
differently or delete the unused one.

Also consolidate the no-resume fallbacks. Today they are repeated in the
card, the detail view model, `ReadingPlanEstimates`, and the session service.
A null resume currently means "no reads yet", "plan complete", or "last read
was the final plan verse"; the UI treats all three as "start at the first
book". Use `PlanProgress.isComplete` and a single `resumeTarget` helper (on
`ReadingPlanSummary`) to distinguish them.

## Expected totals versus materialized totals

`rs_verse_state` rows are created from the external verse inventory. If a book
is not materialized (inventory missing, restore edge, newly added book, or an
empty inventory provider), the list/detail denominator shrinks. With the
current code this can display 100% for a plan that still has unread books.
Use expected totals from the inventory as the denominator. A missing book then
contributes zero read verses and correct progress.

## The goal snapshot is stored but not used for fractions

`rs_day_summary` stores `goal_type` and `goal_value` at write time. Calendar
fractions ignore that snapshot and use the current plan goal. Either:

- use the day summary's goal for historical fractions (recommended, because
  the row was designed to be self-describing); or
- explicitly decide that history is re-evaluated against the current goal and
  document it.

For today, the summary is rewritten using the current plan goal by
`upsertDaySummary`, so today is naturally current.

## Empty, missing, and zero are three different states

`DayProgress.empty` is set only when no summary row exists, but a summary row
with zero verses and zero seconds is non-empty. Since heartbeat/end can write
a zero summary, the calendar can show some zero days as tappable and omit
others. Represent absence with a sparse read and add `hasActivity` to
`DailyProgress`.

## Date storage is inconsistent

`rs_day_summary.rs_date` is stored as `YYYY-MM-DD`; `rs_session.rs_date` is
stored as an ISO timestamp and queried with `date(rs_date)`. Some summary
queries use exact string equality, others use SQLite `date()`. Introduce one
local-day value/normalization helper for reads and writes, and use the same
comparison in every day/range query. This also keeps DST and timezone
behavior centralized instead of handled only by the month loop and its test.

## Month and today are overlapping reads

The detail view model loads today separately from the visible month. If the
visible month contains today, the same day is read twice and can be stale in
one place. Prefer deriving today from the month range when the month is the
current month; otherwise keep a separate today read. Define when either is
refreshed after a session.

## Session daily state has two sources

`SessionProgress` takes verses/seconds from `rs_session` sums and
`goalReached` from `rs_day_summary`. The summary is also derived from
sessions. Pick the summary as the daily read model, keep all writes updating
it, and return `DailyProgress` inside `SessionRuntime`. If session sums must
remain the source during a live session, make that explicit and do not mix
the two in one object.

## Plan config changes while a session is active

`setVerseRead` re-reads the plan on every call for book membership and
completion, while the session UI's goal check uses the config captured at
session start. A goal or book edit mid-session therefore affects different
decisions inconsistently. Decide whether a session uses a snapshot for its
whole lifetime (recommended) or live config, and read it once in the chosen
place.

## N+1 reads hide the data relationships

- plan list: one book query per plan, one resume query per plan;
- day activity: one log query per session;
- detail: four sequential service calls.

These make it look like the facts are independent when they are not. Batch
them in the read-model queries (`reading_plan_book` for all plans, logs for
all session ids, progress for all plans) so the call shape matches the
concept.

## `getBooksStats` returns all 66 books

The real service pads the per-book stats to every book in the Bible; the fake
service in tests returns a sparse list. Consumers therefore see different map
shapes in production and tests. Return only plan books from
`ReadingPlanProgress`.

## `ReadingPlanDetails` is a mutable union of unrelated facts

The same class is used for a plan header, an edit source, a list summary, and
a detail result. Different service methods fill different subsets of its
fields (`totalVerses`, `versesRead`, `todayProgress`, `resumePosition`), and
some fields are never filled at all (`totalChapters`, `booksRead`,
`ReadingPlan.lastRead`). Replace it at the read boundary with immutable
read models; keep it only as an internal command/domain object if still
needed.

## Goal type parsing is duplicated and heuristic

`goal_type` may be `M`, `minutes`, or `verses`. `ReadingPlanDetails` and
`RsDaySummary._isMinutesGoal` both use a "starts with m" heuristic. Normalize
to `GoalType` once at the read boundary and carry the enum in the read models.

# Migration plan

Deliberately incremental. Each step lands one or two read models, converts
their consumer, and trims exactly the service surface that consumer was
using. Three pairing rules keep every step shippable:

- A read model lands together with its first consumer, never "for later".
- A command's return shape changes only in the same step as the caller that
  refetches; no half-converted call chains.
- An old service read is deleted only when its last caller migrates; until
  then it may stay as an adapter that delegates to the read models.

Only the session commands currently return state; every other command in the
slice already returns void or an id and its view model already refetches. The
"services return ids, results, or void" work is therefore concentrated in
steps 6-8.

1. **Day activity log.** Introduce `DayActivity`; move
   `DayActivityLogViewModel` to `getDayActivity`; delete
   `getDetailedProgressFor`, `DetailedProgess`, and the service's
   `SessionDetails`. The manual-session commands already return void and
   refetch, so no command changes. Smallest, most isolated surface.
2. **Edit.** Introduce `ReadingPlanConfig`; move
   `EditReadingPlanViewModel.createExisting` to `getPlanConfig(planId)`.
   `getReadingPlanById` stays (detail and panel still call it). Save and
   delete already return id/void.
3. **Detail, day reads.** Introduce `DailyProgress` and the sparse month
   range; move the detail's `getDayProgress`/`getMonthProgress` calls to
   `getMonthDayProgress`, deriving today from the month when it contains
   today. Lands the stored-goal-snapshot decision for calendar fractions.
4. **Detail, plan reads.** Introduce `ReadingPlanProgress` (with
   `BookProgress`) and the `ReadingPlanSummary` composition; move the
   detail's `getReadingPlanById` + `getBooksStats` calls to
   `getPlanSummary(planId)`. The no-resume fallbacks collapse into
   `resumeTarget`.
5. **Panel.** Introduce the batched `getPlanSummaries()`; move the panel to
   it; delete `getReadingPlansWithProgress`, `getReadingPlans`,
   `getReadingPlanProgress`, and the service's resume exposure. After step 4
   this is a one-screen swap reusing proven reads; it kills the N+1 list
   queries.
6. **Session, checkbox reads.** Move `getVerseReadStates` to the container
   (same signature) and take the checkbox payload off the `setVerseRead`
   return: the command returns ids and the book-completed event, and the
   view model refetches verse states for the chapter.
7. **Session, start.** `startSession` returns the session id; the view model
   reads `getPlanSummary(planId)` (config snapshot + resume target) and
   `getSessionRuntime(sessionId)`. Deletes `ActiveSessionSnapshot` and the
   service-side `ReadingPlanConfig` construction.
8. **Session, runtime.** `heartbeat` returns void and `rolloverSession`
   returns the new session id; the view model refetches
   `getSessionRuntime` after each. Deletes `SessionProgress`. Split from
   step 7 because the timer, day-change, and rollover logic is the riskiest
   code in the slice and deserves its own verification pass.
9. **Cleanup and records.** Delete the last fat reads (`getReadingPlanById`,
   `getBooksStats`), the progress fields on `ReadingPlanDetails`, and any
   remaining adapters; record the read-model-container decision in
   `docs/decisions/` and update `ARCHITECTURE.md` (view models reading from
   a database-owned read-model container is a deliberate exception to
   "view models call only services").

Run `flutter analyze && dart format --output=none --set-exit-if-changed .
&& flutter test` after every step, not just at the end.

# Test plan

- Batch reads match the corresponding per-plan reads.
- A plan with an unmaterialized book has the expected denominator and does
  not report complete.
- Goal changes do not recolor historical months when the stored snapshot is
  used.
- `hasActivity` distinguishes zero-activity rows from absent rows; month
  reads are sparse.
- Month ranges include leap days and DST transitions with one-to-one local
  dates.
- Resume: no reads, mid-book, chapter/book transition, final verse, reorder,
  and complete plan.
- Day activity returns ranges from all sessions with one log batch.
- Session runtime uses the same daily numbers as the panel/detail for the
  same day.
- Editing reads only a config and does not depend on progress completion.
- `getPlanSummaries` returns the same card facts as the individual read
  models.
- After each command, refetching the relevant read model reflects the write.

# Open questions

- Should a session use a plan snapshot for its lifetime, or observe plan edits
  live? (Recommendation: snapshot.)
- Is the expected total from the verse inventory always the right
  denominator, or should progress use materialized verse state once
  inventory/versification can diverge? (Recommendation: inventory.)
- Should the calendar use the stored daily goal snapshot or the current plan
  goal for historical coloring? (Recommendation: stored snapshot.)
- Should the panel route pass a plan id or a config object to detail/edit?
  (Recommendation: id plus a read, to avoid stale partial objects.)
- Should `RsBookStats.resumePosition` and `ReadingPlan.lastRead` be deleted, or
  is a future per-book resume feature planned?
- Should `ReadingPlanConfig` keep `planName`/`totalVerses`/`totalChapters`
  fields that session consumers do not use, or shrink the shape to what each
  consumer reads?
