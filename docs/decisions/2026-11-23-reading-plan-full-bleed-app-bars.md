# Full-Width Reading-Plan Navigator with Pane-Owned Gutters

- Date: 2026-11-23
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

The reading-plan routes live in a nested `Navigator` inside
`ReadingSheet`. Padding that navigator with `EdgeInsets.all(16)` made every
route viewport start at the gutter, but the `Navigator`/`Overlay` clips with
`Clip.hardEdge`. Headers therefore could not place their 48dp icon buttons
without the button paint and hit boxes being clipped. The panes compensated
with `Transform.translate` and `MaterialTapTargetSize.shrinkWrap`, which made
the icons visually line up at the cost of clipped ink effects and undersized
tap targets.

# Decisions

1. **Keep the nested navigator full-width.** Let the routes own the layout
   inset instead of padding the navigator viewport. This keeps the navigator
   and overlay clip boundaries outside the content, so header buttons can
   paint and receive taps normally.
2. **Put the gutter in each pane.** Pane headers are full-bleed app bars;
   body content is padded 16px horizontally (and vertically where the old
   outer container provided it).
3. **Use one shared `ReadingPlanAppBar`.** All reading-plan panes use it so
   centered titles, leading actions, and trailing actions are laid out by
   `AppBar`/`NavigationToolbar` rather than hand-built stacks. The app bar is
   non-primary because the sheet and panes already handle safe areas.
4. **Align with the Material app-bar slots.** The default 56px leading slot
   centers a 48dp icon button so its glyph edge lands at x = 16. Trailing
   actions use a 4px right padding so their glyph edge also lands 16px from
   the right. The left-aligned detail title uses `titleSpacing: 0` to sit
   immediately after the leading slot.

# Implementation Notes

- `ReadingPlanAppBar` lives at `lib/reading_plan/reading_plan_app_bar.dart`.
- Header `IconButton`s keep their full 48dp tap targets. Do not reintroduce
  `Transform.translate` or `MaterialTapTargetSize.shrinkWrap` in these
  headers to compensate for layout; adjust the app-bar slots instead.
- The body padding is per pane, so a pane rendered outside `ReadingSheet`
  (as in widget tests) still has the same gutter.

# Alternatives

- **Pad the navigator but disable clipping.** Keeping the navigator padded
  would still make the gutter a navigator concern and every route would have
  to reason about the clipped viewport. Full-width routes are simpler.
- **Keep hand-built header rows with smaller tap targets.** This preserved
  alignment only by clipping paint and gestures, which is the bug being
  fixed.
- **Use `NavigationToolbar` directly.** `AppBar` already provides the
  leading/trailing slot sizing, action padding, title ellipsis, and theme
  integration, so a raw toolbar would duplicate that behavior.

# References

- `lib/reading_plan/reading_sheet.dart`
- `lib/reading_plan/reading_plan_app_bar.dart`
