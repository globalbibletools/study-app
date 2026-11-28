# Single-Constructor Resolution Migration

- Date: 2026-11-27
- Status: Draft
- Related: [Single-Constructor Dependency Resolution](../decisions/2026-11-27-single-constructor-resolution.md),
  [Vertical Slices](../decisions/2026-11-19-vertical-slices.md)

# Goal

Conform the codebase to the single-constructor decision. This is a pure
wiring refactor: no behavior changes, no test deletions — tests keep covering
the same things, wired the new way. Every PR must pass

```
flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test
```

# Non-goals

- Splitting or redesigning any view model or service.
- Touching the four-layer rules, registration lifetimes, or disposal
  ownership — all unchanged.
- The `log.dart` guarded resolution — sanctioned exception, stays.

# Deviation inventory

**Dual constructors** (`withDependencies` + redirecting default):

- `lib/reading_plan/data_access/rs_database.dart` — `ReadingSessionDatabase`
- `lib/reading_plan/reading_plan_service.dart` — `ReadingPlanService`
- `lib/reading_plan/ui/reading_session_view_model.dart` — `ReadingSessionViewModel`
- `lib/changelog/changelog_service.dart` — `ChangelogService`

**`?? getIt` optional-parameter factories:**

- `lib/reading_plan/ui/reading_plan_detail_view_model.dart` — `create`
- `lib/reading_plan/ui/day_activity_log_view_model.dart` — `create`
- `lib/reading_plan/ui/edit_reading_plan_view_model.dart` — `createNew`, `createExisting`
- `lib/reading_plan/ui/reading_plan_panel_view_model.dart` — `create`

**`navigateTo` helpers with optional dependency/service parameters:**

- `lib/reading_plan/ui/reading_plan_detail_panel.dart`
- `lib/reading_plan/ui/edit_reading_plan_panel.dart` — `navigateToNew`, `navigateToExisting`
- `lib/reading_plan/ui/day_activity_log_panel.dart` — also a mid-method getter
- `lib/reading_plan/ui/reading_sheet.dart`
- `lib/changelog/changelog_view.dart` — `service`, `messenger`
- `lib/changelog/changelog_dialog.dart` — `service`, `messenger`

**Lazy (`late final`) resolutions — must move to construction time:**

- `lib/ui/home/home_manager.dart:95` — `NavigationViewModel`
- `lib/ui/home/panel_area/common/infinite_scroll_view.dart:50-51`
- `lib/audio/audio_player_view_model.dart:152`
- `lib/ui/home/appbar/reference_chooser/reference_chooser.dart:39`

**Mid-method resolutions — must move to construction time:**

- `lib/ui/search/search_manager.dart:136-157` — repeated `UserSettings`
- `lib/ui/home/panel_area/hebrew_greek_panel/chapter.dart:161,376,389`
- `lib/ui/home/appbar/drawer.dart:70,136-137`
- `lib/ui/common/resource_ui_helper.dart:33,45`
- `lib/ui/about/markdown_viewer.dart:71`

(Construction-time field initializers — `final _x = getIt<X>()` in a
constructor or State field — already conform and are left alone.)

**Tests doing construct-then-register double bookkeeping** (construct
explicitly *and* register because a `navigateTo` path resolves the same
objects): the five `test/reading_plan/ui/*_test.dart` files, the reading_plan
service/data tests, the three `test/changelog/*_test.dart` files,
`test/ui/home/home_manager_test.dart`,
`test/ui/home/panel_area/infinite_scroll_view_sync_test.dart`,
`test/ui/home/panel_area/bible_chapter_geometry_test.dart`.

# PR slicing

Docs land first (the decision, this plan, and the `ARCHITECTURE.md` DI
rewrite), because `ARCHITECTURE.md` already operates as a target-state
document that code moves toward, and superseding now stops new code from
being written in the old pattern. Code lands in three PRs.

## PR 1 — reading_plan slice

The epicenter: every deviation shape lives here, plus the largest test
suite. It proves the pattern and produces the reusable stack convention.

1. Add `test/reading_plan/fixtures/` per-slice test stack: builds and
   registers the standard set (in-memory `ReadingSessionDatabase` with the
   test verse inventory, real `ReadingPlanService`/`ReadingSessionService`/
   queries, `ReadingSessionViewModel` wired to the
   `FakeNavigationViewModel`, `FakeMessengerViewModel`,
   `BibleNavigation`), exposes handles for assertions, resets in teardown.
2. Collapse the dual constructors into one: instance config (database name,
   path, legacy migration input) and the verse-inventory seam stay
   parameters; shared references resolve in the constructor. Production
   registration in the service locator supplies the production arguments.
3. Strip `?? getIt` parameters from the four view-model factories.
4. Strip optional `messenger` parameters from the four panel/ sheet
   `navigateTo` helpers; resolve globals up front, construct the child
   view model with instance data only, route.
5. Convert the slice's tests: behavior tests seed the stack then construct;
   flow tests drive `navigateTo` against the stack and assert through the
   handles (`navigationFake.navigatedReferences`, messenger messages).

Ordered commits within the PR: stack, then per-class lib changes with their
test conversions, so the PR reviews as a sequence of small mechanical steps.
If review load is a concern it can split into 1a (database + services +
session view model) and 1b (panel view models + `navigateTo` helpers), but
the same test files are touched by both halves — one PR avoids churn.

## PR 2 — changelog slice

Same recipe at small scale: collapse `ChangelogService`'s dual constructor,
strip `service`/`messenger` from `changelog_view`/`changelog_dialog`, convert
the three test files. Fast follower that proves the pattern travels cheaply
across slices.

## PR 3 — app-wide constructor discipline

The mechanical tail: move every `late final` and mid-method resolution in
the inventory to construction time. Touches `ui/home`, `ui/search`,
`ui/download`, `ui/settings`, `ui/about`, `ui/common`, `audio`. No factories
or tests change shape — mostly removing laziness and hoisting locals to
fields. Parallelizable by directory; a good candidate for delegation if the
agent wants the work split.

# Why not other slicings

- **One PR (~60 files, every test suite):** unreviewable, and a single
  revert would discard the validated reading_plan work over a typo elsewhere.
- **Per-class PRs:** without the stack landing first, each test-file edit
  would be done twice — once to adapt to the class change, again when the
  stack arrives.
- **Docs with the last PR:** the old pattern stays "sanctioned" during the
  whole migration, which is exactly the agent-confusion window this decision
  exists to close.

# Done when

- No `withDependencies` constructor, `?? getIt` parameter, or optional
  dependency parameter on any `navigateTo` helper remains.
- No `late final ... getIt` or mid-method resolution outside `log.dart`.
- Every slice's flow tests run against a per-slice stack; no test both
  constructs an object and registers the same instance.
- `docs/ARCHITECTURE.md`'s dependency-injection section describes reality
  (already rewritten in the docs change that lands first).
