# Shared Design Foundation

- Date: 2026-11-27
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The UI layer has no shared home. Reusable presentation code is scattered
across slices: `lib/ui/common/` is a grab-bag, `reading_plan/ui/` keeps its
own app bar and progress circle, and the home slice keeps the keypad. There
is no token layer at all — colors, sizes, radii, and durations are literal
values repeated at call sites (see
[the inventory](../plans/design-system-inventory.md)).

[Vertical slices](2026-11-19-vertical-slices.md) organize capabilities across
all four layers, but they say nothing about keeping the *presentation layer*
consistent between slices. A developer building a new screen has no single
place to look for a progress indicator, a confirm dialog, or a color, and no
rule for where such a thing should have been put.

The design system plan calls for a shared home before any token or component
work begins, because every extracted piece needs somewhere to land.

# Decisions

1. **`lib/design/` is the shared design foundation.** It holds design
   tokens, atoms, and molecules — presentation only. It never holds
   services, view models, databases, or any knowledge of a domain concept.

2. **Membership is decided by genericity, not by reuse count.** A component
   that is generic — no domain vocabulary in its API, no domain data,
   no domain behavior — may be extracted into `lib/design/` proactively,
   before a second slice needs it. A component that is domain-specific
   stays in the slice that owns the domain, even when other slices render
   it. Pre-extraction is deliberate: it makes the foundation discoverable,
   so new screens reach for a shared component instead of hand-rolling a
   third copy of a stepper or a card.

3. **The foundation is not a vertical slice.** A vertical slice integrates
   one feature across every layer. A shared foundation integrates one
   consistent pattern across a layer — here, the widget layer — for all
   slices. It belongs to the same family as logging, downloads, and
   resources: cross-cutting concerns that multiple slices use, which exist
   to keep slices consistent rather than to deliver a capability.

4. **Foundation components are purely presentational.** They take data and
   callbacks as parameters. They do not call `getIt`, services, or
   view models, and do not hold domain state. A widget that needs service
   or view-model wiring gets a thin container in the consuming slice that
   feeds a presentational component from the foundation.

5. **Presentation code is organized into three named groups.** Atomic
   design's vocabulary maps onto directory names, so classification is
   visible without reading a component's body:

   In `lib/design/`:
   - tokens stay at the root — `theme.dart`, the abstract final constant
     classes, and any `ThemeExtension` (the values everything else is
     built from, not a group).
   - `elements/` — atoms: single-purpose controls (a button, a text
     input, a stepper).
   - `components/` — molecules and organisms: composed controls, small
     dialogs, form groups.
   - `templates/` — shared layouts: page scaffolds, dialog chrome,
     bottom-sheet chrome.

   In each vertical slice:
   - `components/` — domain-specific components (the slice's reusable
     presentation, e.g. a verse list item).
   - `templates/` — domain-specific layouts reused by several views.
   - `views/` — the concrete pages, dialogs, and bottom sheets the app
     navigates to.

   A component moves between groups when its body changes in kind —
   an element that starts composing other elements becomes a component.
   It moves between the foundation and a slice only by the genericity
   rule in decision 2.

# Implementation Notes

- Tests mirror the path under `test/design/` (e.g. `test/design/elements/`).
- The three groups are created as directories when they receive their
  first file, not before; empty directories carry no information.
- `lib/ui/common/` is the legacy location for shared UI. It is not extended;
  its contents migrate into the matching `lib/design/` group when touched,
  with the same opportunistic rule as slices: migrate when worked on, no
  big-bang sweep. Slice `ui/` directories (e.g. `reading_plan/ui/`) likewise
  reorganize into `components/`, `templates/`, and `views/` when the slice
  is worked on.
- Domain-specific widgets that are rendered by multiple slices (for example
  a verse list item) stay in the owning slice, and other slices render them
  under the existing cross-slice widget rules in
  [Vertical Slices](2026-11-19-vertical-slices.md).
- Token definitions and theme construction will live here once the token
  mechanism is decided; `lib/theme.dart` moves to `lib/design/` at that
  point.
- Naming follows the slice conventions: widget files named for their primary
  class without a `_widget` suffix.
- Whether a component is "generic" is judged by its API surface. If a
  component's constructor mentions `ReadingPlan`, `Reference`, or another
  domain type, it is domain-specific; if it mentions percent, label, or
  severity, it is generic.

# Alternatives

- **Keep atomic design's own names (`atoms/`, `molecules/`, `organisms/`):**
  Discarded. The vocabulary is useful for thinking but names groups by
  abstraction level rather than by what a developer is looking for;
  "elements" and "components" say what goes in more directly, and
  "templates" matches the layouts they hold.
- **A single flat `lib/design/` for all foundation widgets:** Discarded.
  The inventory spans a progress circle and a settings row; without
  groups, discoverability degrades to `lib/ui/common/`'s grab-bag drift,
  just with a better address.
- **Extract only on second use (promotion rule):** Discarded. It minimizes
  speculative code but hurts discoverability — the second consumer has
  already hand-rolled a copy by the time promotion triggers, and a new
  developer cannot trust `lib/design/` to contain what the name suggests.
- **`lib/ui/kit/`:** Discarded. The directory will hold tokens, not only
  widgets; "design" covers both.
- **Keep growing `lib/ui/common/`:** Discarded. The name says nothing about
  membership, and it would accumulate the same grab-bag drift the inventory
  found.
- **Treat it as a vertical slice:** Discarded. It has no database, service,
  or view-model layer and delivers no user capability; applying slice rules
  to it would misplace the question. The distinction is: slices integrate
  a feature down the stack; foundations integrate a pattern across the
  stack's top.
- **Foundation components with service access:** Discarded. A shared
  component wired to services becomes a place where business rules hide, and
  it cannot be dropped into a gallery or golden test without seeding the
  locator.

# References

- [Design system inventory](../plans/design-system-inventory.md)
- [Design system plan](../plans/design-system-plan.md) — this decision
  closes plan item 0.1
- [Vertical Slices](2026-11-19-vertical-slices.md)
- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
