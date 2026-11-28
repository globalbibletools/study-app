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

Infrastructure used by several slices (logging, downloads, resources) remains
shared rather than being copied into each slice.

Slices integrate a feature across every layer; shared foundations integrate
a consistent pattern across a layer for all slices. Presentation has one
such foundation: `lib/design/` holds tokens, atoms, and molecules that are
generic — no domain vocabulary in their APIs. Generic components may be
pre-extracted there before a second slice needs them, so the foundation is
discoverable; domain-specific widgets stay in the slice that owns the domain
even when other slices render them. Foundation components are purely
presentational: data and callbacks in, no `getIt`, services, or view models.
The full rules are in
[Shared Design Foundation](decisions/2026-11-27-shared-design-foundation.md).

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

- Dependency injection exists for **shared references**: databases, services,
  and global view models.
- These are things whose lifetime is the process and which several parts of the
  app need. These objects should not be disposed.
- Register shared references in the service locator.
- View models are eagerly initialized because they are global app state.
- Other non-critical references like services and databases can be lazy initialized for
  faster startup.
- Widgets are never registered as shared references.
- Import cycles among shared references are prohibited.
- Declare shared references at the top of the class or static function,
  for example `final _planService = getIt<ReadingPlanService>();`.
- Tests can seed fake versions of shared references to isolate a vertical slice.
  `getIt.reset()` is necessary after each test.

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

Asynchronous work belongs to the view model and is serialized through
`SerialQueue` (`lib/asyncutils/serial_queue.dart`). Queue every async entry
point that mutates view-model state or a shared resource — commands, stream
callbacks, resource callbacks, state refreshses. Pure reads that cannot overlap,
and UI-only state changes, skip the queue. Rationale and alternatives are in
[the decision record](decisions/2026-11-25-serialized-view-model-commands.md);

- Queue the command body in the public method; shared helpers stay private
  and unqueued. A queued body must not await another public queued method
  (it deadlocks on itself).
- Commands read state when they run, not when submitted; an earlier queue
  entry can make a later command a no-op.
- Fast commands made indempotent with `runCoaleseced` need no pending flag to
  block the UI. The rerender is not worth it, and the subsequent command will
  be dropped.
- Use `run` if you want each repeat action to be queued independently.
- If you want to prevent repeat actions from being queued, you have a few options
  - `runCoalesced` - repeat calls run once and share the same result. Use when
    you want all callers to be able to react to the result. Each call will be
    able to run side effects upon completion or failure
  - `runUnique` - repeat calls are dropped with [InFlightError]. Use when only
    the first caller should react to the result with side effects.
- `SerialQueue.close()` is called during the view model's asynchronous
  disposal path and the parent dispose is only called when the queue's pending
  action has completed. This allows us to skip checking dispose state.

