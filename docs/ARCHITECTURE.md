# Architecture

How the app's code is organized and how data flows through it. This
document governs how code *should* be written; the codebase does not fully
conform yet. When making a change, move code toward this document, and when
a rule here conflicts with reality, flag it and fix the doc or the code.

This document is being written incrementally. The layer model, dependency
injection, and the reactivity model below are the agreed foundation; later
sections will cover vertical slices and the page model.

The document is deliberately loose about file organization. Layers are about
responsibilities and what each part is allowed to know, not about folder
layout. When a module is described below, find it by what it does, not by
where it lives.

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

A view model is where async gets tamed. Raw futures from services become
guarded updates: completion is checked against the current state, and stale
answers from abandoned loads (fast chapter switches, closed panels) must
never overwrite fresh ones. Load-token or generation-counter patterns are
the standard tool.

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

