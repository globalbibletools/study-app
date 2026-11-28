# Single-Constructor Dependency Resolution

- Date: 2026-11-27
- Status: In Review
- Supersedes: [Dependency Injection](2026-11-18-dependency-injection.md)
- Superseded By: None

# Context

The dual-constructor pattern (`withDependencies` plus a locator-resolving
default) was adopted so tests could construct classes with fakes without
touching global state. In practice it failed three ways:

1. **Every construction site doubles.** A class with dependencies needs the
   `withDependencies` constructor, a redirecting default constructor, `?? getIt`
   optional parameters on every static factory, and optional dependency
   parameters on every `navigateTo` helper. Adding a dependency touches all of
   them, and the helpers are the sites that get forgotten — the half-used
   `messenger ?? getIt<MessengerViewModel>()` parameters are the residue.
2. **Two sources of truth for wiring.** Tests that pump through `navigateTo`
   must register in the locator anyway, because that is what the production
   path resolves. The result is construct-then-register double bookkeeping,
   where a reader (human or agent) cannot tell which wiring is load-bearing.
   Agents repeatedly misjudged this: sometimes deleting "duplicate"
   registration and breaking flow tests, sometimes threading parameters
   through widgets to avoid the locator entirely.
3. **Explicit passing breaks slice encapsulation.** If opening a child page
   requires the caller to know the child view model's full dependency list,
   every layer must know the transitive wiring of everything it opens.
   `DayActivityLogPanel.navigateTo(context, planId)` should be the whole
   contract.

Constraints that survive from the superseded decision: shared references
need one production wiring site; the dependency list of a class must stay
visible; ownership and disposal rules are unchanged; the locator never holds
widgets.

# Decisions

**Constructors carry instance data only.** Shared references are declared as
`final` fields initialized from the locator at the top of the class:

```dart
class ReadingPlanPanelViewModel extends ChangeNotifier {
  final _queries = getIt<ReadingPlanQueries>();
  final _sessionViewModel = getIt<ReadingSessionViewModel>();
}
```

Constructors only compose instance data — a plan id, a target day, a narrow
function seam such as the verse-inventory provider — as parameters. There is
no shared-reference dependency parameter and no optional `?? getIt` parameter
anywhere. A class may expose additional constructors that select instance
data, such as `ReadingSessionDatabase.inMemory()` for tests, but they do not
change how shared references resolve. A static factory such as `create`
resolves any shared reference it needs before the instance exists at the top
of the factory.

**The locator is the test seam.** Tests seed it: fakes register exactly like
real things. A per-slice test stack registers the standard real-but-cheap set
(in-memory databases, real services) plus the few fakes that genuinely need
stubbing (`FakeNavigationViewModel`, `FakeMessengerViewModel`), so an
individual test overrides a registration only when it needs something
special. Registration is always load-bearing — there is exactly one way a
dependency arrives, so there is never a question of which wiring is required.

**Resolution happens once, at construction.** getIt may be called from the
service locator itself, from `final` field initializers, from static
factories and `navigateTo` helpers resolving the references they use up
front, and from test stacks. Never in methods, getters, `late` fields, or
`static final` fields — those hide dependencies and turn missing
registrations into deep runtime failures or cross-test leakage instead of
construction-time failures.

**The initialized fields are the dependency list.** It stays the design
signal: an oversized set of initialized fields means the class does too
much, and a dependency that would cross sideways across a slice boundary
becomes a narrow function or interface seam (the verse-inventory-provider
approach), which is instance data and therefore a parameter.

**The discriminator: shared references resolve into fields; instance data is
a parameter.** The locator can hold one live instance of a type, so a type
that needs several differently-configured instances at once keeps explicit
constructor parameters and is constructed at its call site.

Kept unchanged from the superseded decision: the registered set stays small;
databases and services register lazily, global view models eagerly;
page-scoped view models are never registered — they are constructed and
disposed by their page, while their dependencies resolve; whatever constructs
a thing disposes it; widgets resolve only global view models; the locator
never holds widgets; cycles are never solved with wiring.

**Sanctioned exception:** the logging infrastructure's guarded resolution
(`log.dart`) must function before and without registration; it keeps its
`isRegistered` check.

# Costs accepted

- Tests always seed the locator, even narrow unit-ish ones. `getIt.reset()`
  discipline in teardown is load-bearing; the failure mode is cross-test
  leakage.
- One live instance per type. Nothing today needs two; the escape hatch is
  explicit parameters at the call site, not locator tricks.

# Implementation Notes

- A per-slice test stack lives at `test/<slice>/fixtures/` and both builds
  and registers the standard set, exposing handles for assertions. Global
  reusable fakes stay in `test/fixtures/`.
- `navigateTo` helpers resolve the global view models they need at the top,
  construct the page's view model through its factory with instance data
  only, then route. Callers never pass dependencies.
- Migration plan and PR slicing: `docs/plans/single-constructor-resolution.md`.

# Alternatives

- **Dual-constructor pattern** — superseded; the three failures above.
- **Pure constructor injection, no locator** — still discarded: every layer
  would have to know the transitive wiring of everything it opens, which is
  the encapsulation failure restated.
- **Lazy or static locator resolution (`late final` / `static final` /
  mid-method)** — still discarded. Lazy resolution defers a missing
  registration to first use; static fields are process-global, survive
  `getIt.reset()`, and leak state across tests. A `final` instance field
  resolves at construction and belongs to the instance.
- **InheritedWidget/Provider-based DI** — still discarded; ties injection to
  the widget tree against the layer rules.

# References

- [Dependency Injection](2026-11-18-dependency-injection.md) — superseded
- [Vertical Slices](2026-11-19-vertical-slices.md)
- `docs/ARCHITECTURE.md` — the construction pattern in full
- `docs/plans/single-constructor-resolution.md` — migration and PR slicing
