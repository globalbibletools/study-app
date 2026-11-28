# Design System Plan

How to get from the current state (see
[inventory](design-system-inventory.md)) to a baseline atomic design system
that serves the views we have and the views we will build. Ordered by
sequence; within each phase, ordered by impact. Nothing here is a decision
record — each numbered item in Phase 0 produces one, per `AGENTS.md`.

The guiding constraint from `ARCHITECTURE.md`: slices move when they are
being worked on, never big-bang. The design system is built the same way —
establish the foundation deliberately, then adopt opportunistically.

## Phase 0 — Decisions (blocking: everything else builds on these)

Each of these needs a decision record in `docs/decisions/` before the
corresponding foundation is built. They are cheap to make now and expensive to
reverse later.

1. **Where the design system lives, and the promotion rule.**
   Decided in
   [Shared Design Foundation](../decisions/2026-11-27-shared-design-foundation.md):
   `lib/design/` holds generic tokens, atoms, and molecules, pre-extracted
   for discoverability; domain-specific components stay in their owning
   slice. This unblocks every extraction in Phase 2.
   *Impact: highest — without it, extracted components have no home and the
   current scatter (reading plan's own app bar, home's keypad) continues.*

2. **Token mechanism.** Decided in
   [Design Token Mechanism](../decisions/2026-11-27-design-token-mechanism.md):
   fill `ThemeData`'s native slots first; `ThemeExtension` only for families
   with no slot (severity palette is the first); brightness-independent
   constants (spacing, radius, motion) in abstract final classes. *Impact:
   high — determines the API surface of everything after.*

3. **Typography and user font scaling.** Deferred as domain-coupled rather
   than mechanism (see
   [Design Token Mechanism](../decisions/2026-11-27-design-token-mechanism.md)):
   the app's most distinctive visual requirement — scripture text size is a
   user setting (`UserSettings` per-surface scales) — currently bypasses
   `TextTheme` via widget params. When revisited, decide how the two systems
   merge: a named type scale whose sizes are computed from
   `baseFontSize × scale × role` at theme construction (tokens remain
   single-sourced, user scaling stays), versus continuing to pass `fontSize`
   params down. Also decide whether `bodyLarge: 18` stays as the base.
   *Impact: high — scripture text is the product; every reading surface
   touches this.*

4. **Semantic color roles, one palette, both brightnesses.** Promote the
   messenger's severity palette and the inline `withValues(alpha: …)`
   variants into named roles (e.g. `primarySubtle`, `scrim`, `successFg`).
   Decide the severity set is app-wide vocabulary (download errors, resource
   prompts will reuse it), not messenger-private. Also decide what the
   scripture text renderer owes dark/light mode (today hardcoded white/black
   in `text.dart`). *Impact: high — removes ~62 off-theme literals and
   unblocks dark/light parity work.*

5. **Motion tiers.** Pick 3–4 durations (e.g. 150/250/500 ms) and 2–3 curves,
   map named tiers onto them, accept the existing values as the draft
   standard. Small decision, makes every future animation consistent.
   *Impact: medium.*

6. **Component conventions.** Naming, constructor surface, and the
   presentational rule: a kit component takes data and callbacks only — no
   `getIt`, no service calls, no `setState` (the widget-layer rules already in
   `ARCHITECTURE.md`, restated for kit eligibility). Components like
   `VerseListItem` need a thin container wrapper before promotion.
   *Impact: medium — mostly codifies what `ARCHITECTURE.md` already implies.*

## Phase 1 — Token foundation (first build, highest leverage)

7. **Build the token layer.** In the new shared slice, define:
   - Color: semantic roles + severity family + keep/extend the surface ramp
     (it's already good).
   - Type: the scale from decision 3, including scripture sizes.
   - Spacing: the de facto 4-grid as named steps.
   - Radius: collapse 14 values to ~4 tiers (the clustering at 8/12/14/24
     says sm/md/lg/full already wants to exist).
   - Motion: tiers from decision 5.
   Wire into `darkTheme`/`lightTheme` so `Theme.of(context)` serves everything.
8. **Tokenize the worst offenders first:** messenger severity palette,
   search keyboard, overlay scrims, scripture text renderer. These four close
   the dark/light parity gap in the same pass.
   *Impact: high — every subsequent change inherits correct values; migration
   is mechanical (grep-driven) and low risk.*

## Phase 2 — Extract components (opportunistic, driven by the inventory)

Extraction order within this phase is by reuse count, not by atomicity —
extract what is duplicated today, leave the rest in place until touched.

9. **Settings row / chooser row.** Six hand-rolled instances across the
   settings sections; a `SelectionRow` molecule (with segmented, list, and
   slider variants) deletes the most code per hour of any item in this plan.
   Rewriting the sections also fixes their `getIt`+`setState` layering
   violations at the same time.
10. **Confirm dialog.** Already instantiated twice; trivial once tokens exist.
11. **Bottom-sheet scaffold.** Unify `ReadingSheet` and
    `ParallelTranslationsSheet` chrome + view-model disposal pattern.
12. **Promote existing, already-clean atoms:** `ProgressCircle`,
    `NumberStepper`, `SparkleIconWidget`, severity icons, badge/pill,
    `WordPopup`. These are extraction-ready as-is.
13. **Promote molecules that need a container split first:** `VerseListItem`
    (split gloss-service wiring into a container), `_MessageCard`,
    `ReadingPlanCard`'s card container, the overlay/celebration family.
14. **App bar family.** Generalize `ReadingPlanAppBar` into the secondary app
    bar; align `HomeAppBar` and default `Scaffold` app bars on the same
    tokens.
    *Impact: rises over time — every new screen reaches for these first.*

## Phase 3 — Enforcement systems (make the baseline durable)

This is what separates a design system from a tidy codebase.

15. **Component gallery.** A test-only (or debug-route) page rendering every
    token and component in both brightnesses. Also serves as living
    documentation; doubles as the surface for visual review.
16. **Golden tests.** Pin the gallery and key components (`VerseListItem`,
    `ReadingPlanCard`, messenger card, settings rows). Golden tests on the
    tokens themselves are what make Phase 1's choices enforceable.
17. **Lint for raw values.** A repo test or custom lint failing on new
    `Color(0x…)`/`fontSize:` literals outside the token slice. Adoption stays
    opportunistic, but regressions stop.
    *Impact: high — without this, the foundation erodes in months.*

## Phase 4 — Template unification (as views are touched)

18. **Page/overlay template conventions.** Write down the matrix: when a
    surface is a scaffold page vs bottom sheet vs full-screen dialog (the
    word-study flow's precedent), and the overlay stack order (messenger top,
    word study, keypad, celebrations). Mostly codifying what `HomeScreen`
    already does; document it where the inventory's "Templates" section lives.
19. **Migrate the remaining views' inline values to tokens as each slice is
    worked on.** No dedicated effort; the Phase 3 lint tracks the remainder.
    *Impact: medium — mostly debt retirement.*

## Phase 5 — Future-facing (once the baseline holds)

20. **Dynamic type / accessibility.** Integrate `TextScaler` and platform
    text scaling with the token scale from decision 3; audit contrast on the
    severity and surface ramps. The token layer makes this a token change
    instead of a sweep.
21. **Feedback and celebration family.** `ConfettiOverlay`, `GlowingButton`,
    `GuideBubble`, sparkle marks — formalize the "positive feedback" visual
    language once reading-plan features stabilize.
22. **RTL parity for every kit component.** Directionality is already
    parameterized in the reading components; make it a kit-level guarantee
    so future components inherit it.

## Sequencing summary

| Order | Work | Why this position |
|---|---|---|
| 0.1–0.6 | Decisions + records | Everything downstream inherits these; cheap now |
| 1.7–1.8 | Token layer + offender migration | Highest leverage per effort; mechanical |
| 2.9–2.14 | Component extraction | Requires 0.1 (home) + 1 (tokens); ordered by duplication |
| 3.15–3.17 | Gallery, goldens, lint | Locks in Phases 1–2; do before broad adoption |
| 4.18–4.19 | Template conventions + opportunistic migration | Leverages 3; documentation-heavy |
| 5.20–5.22 | A11y/dynamic type, feedback family, RTL parity | Only meaningful on a stable foundation |

Deliberately *not* in this plan: a big-bang restyle. Every visual value
proposed as a token is one already in use somewhere in the app; Phase 1
formalizes the current design rather than replacing it. A restyle, if wanted,
becomes a token-layer change later — which is the point of having one.

Verification for any code work remains
`flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
per `docs/DEVELOPMENT.md`.
