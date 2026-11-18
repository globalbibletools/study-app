# Four-Layer Architecture

- Date: 2026-11-18
- Status: Accepted
- Supersedes: None
- Superseded By: None

# Context

The app reads and studies scripture against a local SQLite database, with
business rules (what a completed book is, when a gloss exists) that must
survive UI churn, and UI that must be testable without touching the
database. Without enforced boundaries, business rules leak into widgets,
reactivity types leak into databases, and every change ripples across the
whole stack.

We needed a layering rule that is testable in practice — something that
tells you *which* file to open when a change is needed, and flags a boundary
as wrong when it doesn't.

# Decisions

The app is built from four layers, each depending only on the layer below:

    Widget → ViewModel → Service → Database

- **Calls flow one way, down.** Widgets call view models, view models call
  services, services query databases. Nothing ever calls up the stack.
- **Reactivity flows back up.** Lower layers announce changes; upper layers
  subscribe. (The mechanics are a separate decision: see
  [Reactivity Patterns](2026-11-18-reactivity-patterns.md).)
- **Each layer has one reason to change**, which is the practical test for
  where code belongs: the database changes when data shape changes, the
  service when business rules change, the view model when interaction
  changes, the widget when visuals change. If a business-rule change forces
  a widget edit, or a visual change forces a database edit, a boundary is
  wrong.

Layers are about responsibilities, not folder layout. Modules are found by
what they do, not where they live.

# Implementation Notes

- The codebase does not fully conform yet. When making a change, move code
  toward the layer model and flag conflicts so the doc or code gets fixed.
- No UI concepts (`BuildContext`, `GlobalKey`, widgets, navigation) below
  the ViewModel layer; no `ChangeNotifier`/`ValueNotifier` below Service.
- View models may reference other view models only *up* the ownership tree,
  never sideways; sideways needs signal shared state belongs in an ancestor
  view model or a service.
- Async is tamed in the view model: stale results from abandoned loads must
  never overwrite fresh ones (load-token / generation-counter patterns).
- Full layer-by-layer knowledge rules are in `docs/ARCHITECTURE.md` — it is
  the authoritative detail; this record exists to capture the decision and
  the why.

# Alternatives

- **Three layers (widget/service/database, no view models):** Discarded.
  Widgets would hold application state and the "reason to change" test
  collapses — interaction changes and visual changes land in the same files.
- **Widgets calling services directly:** Discarded. Business rules drift
  into the widget tree and async guarding (stale-load protection) has no
  single home.
- **Folder-driven architecture (layering by directory):** Discarded. The
  rule is about what each part is allowed to know, not where it sits;
  folder structure says nothing about responsibilities.

# References

- `docs/ARCHITECTURE.md` — the layer model in full
- [Reactivity Patterns](2026-11-18-reactivity-patterns.md)
- [Dependency Injection](2026-11-18-dependency-injection.md)
