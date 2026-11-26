# Architecture

How the app's code is organized and how data flows through it. This
document governs how code *should* be written; the codebase does not fully
conform yet. When making a change, move code toward this document, and when
a rule here conflicts with reality, flag it and fix the doc or the code.

## The four layers

The app is built from four layers, each depending only on the layer below:

```
Widget ──calls──▶ ViewModel ──calls──▶ Service ──queries──▶ Database
   ▲                 │                     │
   └── subscribes ───┴──ChangeNotifier/ValueNotifier/streams──▶ (service emits)
```

Calls flow one way, down. Reactivity flows back up: lower layers announce
changes, upper layers subscribe. Nothing ever calls up the stack.

Each layer has a distinct *reason to change*, which is the practical test
for whether code belongs in it:

- **Database** changes when the shape of the data changes.
- **Service** changes when business rules change.
- **ViewModel** changes when the interaction changes.
- **Widget** changes when the visuals change.

If a change to a business rule forces edits in a widget file, or a visual
change forces edits in a database, a boundary is wrong.

### Database

Owns the bytes on disk: opens the SQLite file, translates rows into domain
models, and runs queries. That is all.

- Knows: sqflite, its own domain models, its own schema and migrations.
- Does not know: other databases, services, settings, or Flutter's
  reactivity types. No `ChangeNotifier` or `ValueNotifier` here.
- Does not know *why* anyone wants the data.

When a database needs something owned elsewhere, it declares that need and
lets the caller provide it, rather than reaching sideways.

Services get atomic access through a **unit of work**. A database's
`unitOfWork` method runs a closure inside one transaction and hands it a
`UnitOfWork` exposing the database's repositories bound to that transaction.
Success commits; a throw rolls back; there is no manual commit. Repositories
take their executor in the constructor and never open transactions of their
own. Units of work never nest, because sqflite has no nested transactions.

Lifetime is not the database's concern: whoever opens a database closes it.
Some databases are process-wide singletons (the HebrewGreek text); others
are opened per resource on demand (a downloaded bible), and deciding which
is a service-layer decision.

### Service

Holds business rules and orchestrates data sources: what counts as a book being
complete, whether a gloss exists yet and what should happen when it does not.

- Knows: databases and other services (few).
- Does not know: widgets, view models, navigation, `BuildContext`,
  `GlobalKey` — anything from the UI world.

Services can expose queries of persisted state, but they should otherwise be
stateless except in cases where caching can improve preformance.
This is invisible to callers; they ask and the service figures out how to answer.

Services talk to view models only through return values and streams. A
service never receives a view model.

### ViewModel

Holds application and UI state, translates user intent into service calls,
and exposes the results in a form widgets can subscribe to cheaply and precisely.

- Knows: services, references, domain models, and Flutter's *foundation*
  reactivity types (`ChangeNotifier`, `ValueNotifier`, `Stream`).
- Does not know: the widget tree. No `BuildContext`, no `GlobalKey`, no
  widgets. It exposes state; it does not decide where or how it is drawn.

A view model is where async gets tamed. Mutating work becomes serialized
commands, and read results become guarded updates: completion is checked
against the current state, and stale answers from abandoned loads (fast
chapter switches, closed panels) must never overwrite fresh ones. Use the
mechanisms described in [Asynchrony in view
models](#asynchrony-in-view-models).

View models may reference other view models, but only along the ownership
tree: a view model may know view models *above* it (its owner, an
app-scope view model) — never sideways. A page-scope view model depending
on a sibling page-scope view model is a sign the shared state belongs in an
ancestor view model or a service.

Lifetime follows the page that owns it: created with the page, disposed
with the page, and self-cleaning — a view model cancels its own
subscriptions and disposal is safe even with async work in flight.

### Widget

Renders what the view model exposes and forwards user gestures to it.

- Knows: its view model, theming, l10n, layout, animations.
- Does not know: services, databases, or any decision logic beyond "if
  this flag, show that".
- Never owns data. A `StatefulWidget`'s mutable fields hold transient
  widget-local concerns (scroll controllers, animation controllers), never
  domain data.

Because data lives in the view model, a widget that constructs a view model
also owns and disposes it; a widget disposing something it did not
construct is a layering violation. Widgets subscribe with
`ListenableBuilder` / `ValueListenableBuilder`, scoped as narrowly as
possible, and never use `setState` to propagate data changes upward or
sideways.

## Vertical slices

A vertical slice is everything needed to deliver one capability: its
database and models, service, local view models, and widgets. Layers answer
"what kind of code is this?"; slices answer "what does this code belong
to?" A slice contains multiple layers, and every file still obeys the layer
rules above.

### Directories make slices visible

Each slice owns a directory under `lib/<slice>/`, with tests under
`test/<slice>/`. A file belongs where its capability belongs, not in a
global `services/` or `ui/` tree. The directory is the visible expression of
the boundary, not the boundary itself: moving files together without the
ownership rules below is only cosmetic.

Imports use `package:gbt/<slice>/...` so files do not depend on their
physical depth. A slice directory is not a new layer. Keep database,
service, view model, and widget files distinguishable by name and
responsibility: widget files are named after their primary class without a
`_widget` suffix; non-widget roles keep their `_service`, `_view_model`, and
`_database` suffixes.

### State ownership

State that changes together and serves one capability lives inside that
slice. Most state stays local. A local view model is paired with the widget
that constructs, owns, disposes, and uses it; no other slice reaches into
it.

When state must be shared, promote it deliberately to a globally registered
view model with a clear owning slice, rather than duplicating it or reaching
into another slice's local state. `NavigationViewModel` is the canonical
example: it is global by design and may be used from any slice. State
changes still go through its methods, per [Who writes](#who-writes).

### Cross-slice references

Coupling is governed by ownership, not by forbidding references. A slice may:

- render another slice's widgets, which is necessary to compose UIs. The
  widget remains paired with its own local view model; callers do not pass
  that view model around or call into it.
- use globally registered view models, such as `NavigationViewModel`.
- call into another slice's services.

A slice may not:

- reference another slice's database classes. The owning service is the only
  entry point to that data.
- talk to another slice's local view models outside their paired widgets.

Infrastructure used by several slices (logging, downloads, resources,
cancellation) remains shared rather than being copied into each slice.

### Surface area

Keep the surface area of a slice small. This is a design goal, not an
enforcement rule yet. The first phase is organization and ownership;
narrowing each slice's public interface so coupling can be controlled comes
later. When in doubt, expose intent through the slice's service or global
view model methods rather than widening what may cross the boundary.

### Migration

Slices move when they are being worked on; there is no big-bang
reorganization. Tests mirror the slice path under `test/<slice>/`, the same
convention as `lib/services` → `test/services` without a `lib/` segment.

## Dependency injection

Dependency injection exists for **shared references**: databases, services,
and global view models. These are things whose lifetime is the process and
which several parts of the app need. The registered set stays small; most
things are scoped to the view that cares about them.

### The construction pattern

Every class that has dependencies offers both of these:

- A **`withDependencies` constructor** taking every dependency explicitly.
  This is the test seam: tests construct the class with fakes directly,
  without touching getIt.
- A **default constructor** that fills the same dependencies in from getIt.
  This is the production seam, and it is the sanctioned way dependencies
  arrive: injection happens through getIt.

Because of this, `getIt` may be called from exactly two places: the service
locator itself, and these default constructors. Nowhere else — not in field
initializers, not mid-method, not `late final x = getIt<T>()`. Resolution
happens once, at construction; afterwards the object simply has its
dependencies and never reaches for the locator again. (Classes that resolve
lazily after construction — a current habit — hide their dependencies from
callers and make test fakes impossible.)

Ask for exactly what the class uses, nothing more. A short dependency list
keeps test construction small, and an oversized one is a visible signal that
a class does too much. Dependencies that would cross sideways across a
boundary become narrow function or interface seams — the
verse-inventory-provider approach — so the fake can be a one-line lambda.

### Registration and lifetime

All shared composition happens in the service locator: if a class is shared,
it is registered there, and nowhere is it constructed ad hoc.

- **Databases and services**: registered lazily. They initialize on first
  use, and `registerSingletonAsync` ensures concurrent first-callers share
  one `init()` rather than racing. Only what the first frame genuinely
  needs is awaited at startup — everything else stays lazy so the app does
  not block on resources it may not open this session.
- **Global view models**: registered eagerly, since they are global — the
  app cannot be half-initialized. Use the async registration when they
depend on async things like settings.

Ownership and disposal is the flip side of registration: **whatever
constructs a thing disposes it.** Registered singletons live for the process
and are never disposed by a widget; page-scoped view models are constructed
*and* disposed by their page, and never registered. A widget disposing an
object it did not construct is a layering violation (the registered-but-
widget-disposed manager is the failure mode to avoid). The test: if it needs
disposal when a screen goes away, it cannot be registered.

Cycles are not a wiring problem. Lazy singletons make mutual dependencies
runnable, which only hides the real issue: a missing third thing that owns
the shared concern, or a wrong ownership split. The locator never contains a
workaround for a cycle.

Widgets never participate: the locator holds databases, services, and global
view models — never widgets — and no widget asks the locator for anything except
global view models. A page constructs its view model; children receive theirs
through constructors from their parent.

## Reactivity

The principle: balance rerender performance against ergonomics. Both halves
matter — a pattern that rebuilds the smallest possible subtree but spreads
boilerplate across every screen is not a win. A rebuild costs

    frequency x audience

where frequency is how often a change fires and audience is how much subtree
rebuilds per notification. Rebuilding a view a few times a second is cheap;
rebuilding it every frame is not; rebuilding many screens on every change is
not.

### The three tools

- **`ChangeNotifier`** — the default for view models. One notifier for a
  cohesive batch of state that changes together, one `ListenableBuilder` per
  screen region. Use for state that changes at human interaction frequency,
  not frame frequency.
- **`ValueNotifier`** — a per-field escape hatch *within* a view model, used
  when one field changes much more often than the rest (scroll sync, audio
  position, animation-adjacent state). Its job is to carve the audience down
  to the subtree that actually cares.
- **`Stream`** — for events with no meaningful "now". Use when the current
  value is not needed and subscribers only care about what happens after
  they subscribe. These should be less common than state notifiers. (Example:
  `NavigationViewModel.hardNavigation` is a command, not a state — nobody
  needs to ask "what is the current hard navigation?".)

The discriminator between state and event: if a late subscriber must see the
current value to render correctly, it is state — notifier. If it only cares
about future occurrences, it is an event — stream.

### Decision procedure

Start boring, demote on evidence:

1. Default the whole view model to a `ChangeNotifier`.
2. When a field starts changing at frame-ish rates, promote that field to a
   `ValueNotifier` and shrink the `ListenableBuilder` around its consumers
   to the smallest subtree that needs it.
3. Never promote speculatively — the split is justified by an observed
   rebuild storm, not a predicted one.

Guard every notification: `notifyListeners()` and `value =` fire only when
the value actually changed. For discrete values, equality checks; for
continuous values, a tolerance. `NavigationViewModel` dropping position
updates within a tolerance is the canonical example.

If one `ChangeNotifier` has listeners across many unrelated screens, that is
a cohesion problem before it is a notifier-choice problem: the view model is
probably holding several unrelated kinds of state and should be split.
Splitting the view model fixes the audience; a per-field `ValueNotifier`
only narrows who hears about one field.

### Who writes

View model state is written only by the view model. All changes go through
view model methods, where guards, persistence, and side effects live in one
place. (There are violations of this in the code today to be addressed.)

Widgets are given **`ValueListenable`**, never `ValueNotifier`. The read
side is public; the write side stays inside the view model. `ChangeNotifier`
view models are inherently read-only to widgets, since their state changes
only through methods.

### Streams across layers

Services announce changes through streams rather than callback registries.
Streams do not have to stop at the view model: a view model may consume a
service stream and republish it as notifier state, or may map a stream into
a new stream. Mapping may well become the preferred pattern for change
notification originating at a database, but that is not yet decided.

Whatever the endpoint, a widget never subscribes to a service stream
directly — doing so makes the widget do view model work. View models own
their subscriptions: every subscription and notifier is disposed with the
view model, and streams used for events are broadcast.

## Asynchrony in view models

Asynchronous work belongs to the view model. Two mechanisms cover it:

- **`SerialQueue`** is the default for commands and other work that must happen
  in order.
- **`CancellationScope`** is for publishing the result of a read when a newer
  read makes an older one irrelevant.

### Serialized commands

Use `SerialQueue` (`lib/asyncutils/serial_queue.dart`) for every operation that
mutates view-model state or a shared resource: lifecycle transitions, user
commands, rollover, heartbeat flushes, and similar work. The queue makes
ordering explicit instead of depending on where `await` happens to yield. Its
rationale and alternatives are in [the decision
record](decisions/2026-11-25-serialized-view-model-commands.md).

- Queue the command body directly in the public method. Shared implementation
  helpers stay private and unqueued; a queued body must not await another
  public queued method, or it deadlocks waiting on itself.
- Commands read state when they run, not when they were submitted. An earlier
  queue entry can make a later command a no-op.
- Coalesce redundant periodic work with `runCoalesced`; a newer tick or
  heartbeat shares the pending job instead of adding more work.
- A failed command completes its own future with the error but does not block
  later commands.
- `SerialQueue.close()` rejects new work, drops pending work, and waits for the
  running command. View models call it during their asynchronous disposal path.
- Pure reads and UI-only state changes do not need the queue.

The queue is not cancellation. A running command finishes; the queue controls
what starts next. Do not use cancellation to order commands: a superseded
command may already have written to the database, and cancellation only stops
the caller from observing the result.

### Latest-wins reads

Cancellation here means **supersession**: a newer invocation of a read makes an
older in-flight read irrelevant. It does not abort the underlying I/O; the old
request may still finish, but its result must not overwrite the newer one.

Use `CancellationScope` (`lib/asyncutils/cancellation.dart`) when an operation:

1. awaits I/O;
2. can be invoked again before it finishes;
3. has no domain side effects beyond publishing the result of the read.

The canonical example is loading audio for a chapter while the user keeps
navigating: the newest chapter must win, and an older load must not later set
the reference, error, or playback state. If an operation writes domain state,
route it through the queue instead.

A scope belongs to the object whose state the operation publishes, one scope
per operation, not one per call. The operation's entry point starts a run and
contains its whole body; every `await` in that body, including awaits inside
helpers, goes through the run's guard:

```dart
class ChapterLoader {
  final _loadScope = CancellationScope();

  Future<void> load(Reference reference) {
    return _loadScope.run((guard) async {
      final chapter = await guard(_fetch(reference));
      await _apply(guard, chapter);
    });
  }

  Future<void> _apply(Guard guard, Chapter chapter) async {
    final text = await guard(_render(chapter));
    _chapter.value = text; // only the current run gets here
  }

  void dispose() {
    _loadScope.cancelAll();
    // ...
  }
}
```

Pass `guard` to helpers rather than capturing the scope or token inside them:
it keeps the cancellation dependency visible in the signature and keeps every
await guarded. A guard checks before waiting and again when the future settles.
If the run was superseded, a value and an error both become `CancelledError`.

Call `cancelAll()` in `dispose()` for any owner with a live scope. This does not
await the in-flight operation; it only ensures it cannot act on a disposed
object.

### Handling `CancelledError`

`CancelledError` is control flow, not a failure. It means *another invocation
now owns this state*. The rules:

- **Inside a run, let it escape.** Put `on CancelledError { rethrow; }` before
  any generic `catch`. Never log it, reset state, or show an error in response
  to it.
- **At the call site, handle it only where you can act on it.** Usually that is
  an early `return`, because the newer invocation is responsible.
- **Fire-and-forget call sites may leave it unhandled.** The global handler in
  `main.dart` discards `CancelledError` without logging while genuine errors
  are still logged. Do not wrap such a call in a generic catch just to silence
  it.
- **A catch-all that wraps a run must rethrow it first.** Otherwise abandonment
  becomes a user-visible failure.
- An inner run's `CancelledError` crossing into an outer run remains
  cancellation; the outer guard rethrows it or raises its own.

User-initiated download cancellation is a different concern: `CancelToken`
signals an explicit user decision, and `DownloadCanceledException` is an
expected failure surfaced to the UI. It is not supersession and does not use
`CancellationScope`.
