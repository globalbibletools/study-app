# Vertical Slices

- Date: 2026-11-19
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The code is currently split by technical layer: `lib/services/` and
`lib/ui/` each contain pieces of every capability. A feature such as audio
is spread across `services/audio/`, `ui/home/audio/`, and call sites in
`ui/home/`. Horizontal grouping tells us what kind of code a file is, but
not what it belongs to, so a change to one capability touches several parts
of the tree and it is easy to miss one.

The four-layer architecture governs responsibilities and allowed
dependencies. Vertical slices are a separate concern: they decide what
belongs together, what state is owned where, and where coupling is allowed.
Directories are only the visible expression of those boundaries — they are
not the boundary themselves.

# Decisions

1. **Organize the codebase into vertical slices.** A vertical slice is
   everything needed to deliver one capability, from persistence through
   service, view model, and UI.
2. **Directories organize slices.** Each slice owns a directory under
   `lib/<slice>/`, with tests under `test/<slice>/`. A file belongs where
   its capability belongs, not where its technical layer happens to live.
   The directory makes the boundary visible; it does not define it.
3. **Slices isolate cohesive state.** State that changes together and
   serves one capability lives inside that slice. State stays local unless
   sharing is deliberate; shared state is promoted to a globally registered
   view model with a clear owning slice rather than duplicated or reached
   into from elsewhere.
4. **Coupling is governed by ownership, not by forbidding references.**
   Slices are allowed to:
   - render another slice's widgets, which is necessary to compose UIs;
   - use globally registered view models, with `NavigationViewModel` as the
     prime example;
   - call into another slice's services.

   Slices are not allowed to:
   - reference another slice's database classes;
   - talk to another slice's local view models outside their paired
     widgets.
5. **Keep the surface area of a slice small.** This is a design goal, not
   an enforcement rule yet. For now we concentrate on organization and
   ownership; narrowing the public interface of each slice so coupling can
   be controlled is a later step.
6. **Layer boundaries remain authoritative.** Co-locating files in a slice
   does not permit a widget to call a service directly. The dependency
   direction and knowledge rules in
   [Four-Layer Architecture](2026-11-18-four-layer-architecture.md) still
   apply within every slice.

# Implementation Notes

- Imports use `package:gbt/audio/...` so files do not depend on their
  physical depth.
- A slice directory is a grouping, not a new layer. Keep database, service,
  view model, and widget files distinguishable by name and responsibility.
  Widget files are named after their primary class without a `_widget`
  suffix; non-widget roles keep their `_service`, `_view_model`, and
  `_database` suffixes.
- Rendering another slice's widget is normal composition. The widget remains
  paired with its own local view model; callers do not pass that view model
  around or call into it.
- A globally registered view model is shared state by design and may be used
  from any slice. State changes still go through its methods so its
  invariants stay in one place.
- Another slice's services may be called directly. Its database classes may
  not; the owning service is the only entry point to that data.
- Narrowing cross-slice interfaces is deferred until slice ownership is
  established. The current rule is about which kinds of things may cross,
  not how small each public API is.
- Tests mirror the slice path under `test/<slice>/` (the same convention as
  `lib/services` → `test/services`, without a `lib/` segment).
- Migrate incrementally. Slices move when they are being worked on; there is
  no big-bang reorganization.

# Alternatives

- **Keep the layer-first layout:** Discarded for capabilities that span the
  stack; it hides ownership and makes changes easy to miss.
- **Group directories without assigning ownership:** Discarded. Moving files
  together is cosmetic if any slice can still reach another slice's
  database or local view models.
- **Forbidding all cross-slice references:** Discarded. UI composition,
  global view models, and services are legitimate ways for slices to
  cooperate.
- **Narrow interfaces enforced now:** Deferred. It would stall the
  organization work; first establish ownership, then tighten surfaces.
- **A full `lib/features/` hierarchy:** Not chosen yet; moving every slice
  at once is unnecessary churn. `lib/<slice>/` is the convention until a
  concrete need for another level appears.
- **Slices that bypass layers:** Discarded; slice grouping must not become
  a license for widgets to call services or databases.

# References

- `docs/ARCHITECTURE.md` — layer model and dependency rules
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- `lib/audio/` — the first vertical slice
