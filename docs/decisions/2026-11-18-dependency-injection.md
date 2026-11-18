# Dependency Injection

- Date: 2026-11-18
- Status: Accepted
- Supersedes: None
- Superseded By: None

# Context

Shared references — databases, services, global view models — live for the
process and are needed by several parts of the app. We need a way to get
them to consumers that (a) keeps the production wiring in one place,
(b) makes tests able to construct any class with fakes without touching
global state, and (c) does not turn every widget into a plumbing pass-through.

A prior habit made things worse: classes resolving dependencies lazily
after construction (`late final x = getIt<T>()`) hides dependencies from
callers and makes test fakes impossible.

# Decisions

Use a **getIt service locator for shared references only** — databases,
services, and global view models. The registered set stays small; most
things are scoped to the view that cares about them. Widgets never
participate beyond asking for global view models.

**Dual-constructor pattern.** Every class with dependencies offers both:

- a **`withDependencies` constructor** taking every dependency explicitly —
  the test seam; tests construct with fakes directly, no getIt involved;
- a **default constructor** filling the same dependencies in from getIt —
  the production seam, and the only sanctioned way dependencies arrive via
  injection.

**getIt is called from exactly two places:** the service locator itself and
default constructors. Never in field initializers, never mid-method. All
resolution happens once, at construction; afterwards the object simply has
its dependencies.

**Ask for exactly what the class uses.** An oversized dependency list is a
visible signal a class does too much. Dependencies that would cross a
boundary sideways become narrow function or interface seams (the
verse-inventory-provider approach), so a fake can be a one-line lambda.

**Registration and lifetime:**

- Databases and services register lazily; `registerSingletonAsync` ensures
  concurrent first-callers share one `init()` rather than racing. Only what
  the first frame genuinely needs is awaited at startup.
- Global view models register eagerly (the app cannot be half-initialized),
  using async registration when they depend on async things like settings.
- **Whatever constructs a thing disposes it.** Registered singletons live
  for the process and are never disposed by a widget; page-scoped view
  models are constructed and disposed by their page and never registered.
  The test: if it needs disposal when a screen goes away, it cannot be
  registered.

**Cycles are never a wiring problem.** Lazy singletons can make mutual
dependencies runnable, but that only hides the real issue — a missing third
thing that owns the shared concern, or a wrong ownership split. The locator
never contains a workaround for a cycle.

# Implementation Notes

- All shared composition happens in the service locator; shared classes are
  registered there and never constructed ad hoc elsewhere.
- The registered-but-widget-disposed manager is the failure mode to avoid
  (registering something that a widget then disposes).
- A page constructs its view model; children receive theirs through
  constructors from their parent.
- Full detail is in `docs/ARCHITECTURE.md` "Dependency injection".

# Alternatives

- **Pure constructor injection, no locator:** Discarded. Shared references
  would have to be plumbed through the widget tree to reach deep consumers,
  making every widget a pass-through.
- **getIt resolution anywhere (`late final` / mid-method):** Discarded — the
  prior habit this decision replaces. It hides dependencies and makes test
  fakes impossible.
- **InheritedWidget/Provider-based DI:** Discarded. Ties injection to the
  widget tree, which conflicts with the layer rule that nothing below
  ViewModel knows about widgets; also awkward for non-UI consumers.

# References

- `docs/ARCHITECTURE.md` — the dependency injection model in full
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
