# Home Common UI

## Overview
Houses shared widgets, gesture handlers, visual overlays, and synchronization controllers used throughout the main home reading views.

## Interface
- `cutout_view.dart:SpotlightObject`: Configuration model specifying spotlight focus target via `GlobalKey`, local `Rect`, or global screen `Rect`.
- `cutout_view.dart:CutoutRect`: Value object storing resolved cutout dimensions, inflation margins, and corner radii.
- `cutout_view.dart:TouchState`: Enum controlling hit testing behavior across spotlight masks (`allowAll`, `allowUnderSpotlight`, `disableAll`).
- `cutout_view.dart:CutoutView`: Widget placing a darkened spotlight overlay on top of content with cutout windows.
- `cutout_view.dart:CutoutViewState`: State class managing dynamic coordinate resolution and cutout invalidation.
- `guide_bubble.dart:GuideBubble`: Instructional tooltip positioned dynamically above or below a spotlighted target rectangle.
- `glowing_button.dart:GlowingButton`: Stateful animated widget rendering a continuous traveling light stroke around its rounded border.
- `navigation_view_model.dart:Anchor`: Immutable reference plus start/end edge used as one end of a sync interval.
- `navigation_view_model.dart:SyncPosition`: Immutable verse interval with progress `t` shared between synchronized panels.
- `navigation_view_model.dart:HardNavigation`: Event emitted for explicit navigation that should dismiss transient UI.
- `navigation_view_model.dart:NavigationViewModel`: Single source of truth for position, display reference, chapter anchor, active scroll source, and chapter persistence.
- `zoom_wrapper.dart:ZoomWrapper`: Pinch-to-zoom container providing focal-point-based scaling clamped between 0.5x and 5.0x.
- `zoom_wrapper.dart:CustomScaleGestureRecognizer`: Multi-touch scale recognizer rejecting single-pointer scroll conflicts.

## Invariants
- `NavigationViewModel` tracks three different granularities: continuous position, continuously updated display reference, and a chapter-level anchor that only explicit navigation may change. Scroll reports never move the anchor, so panels are not remounted mid-scroll.
- `NavigationViewModel` ignores scroll reports from passive panels when another panel is the active source, preventing infinite feedback recursion.
- Seeks and manual navigation respect the active-source gate; manual navigation clears the active source first.
- `ZoomWrapper` clamps effective scaling strictly within range `[0.5, 5.0]`.
- In `TouchState.allowUnderSpotlight`, hit tests pass through exclusively within the inflated bounds of active cutouts.

## Side Effects
- Emits hard-navigation events over a broadcast `Stream<HardNavigation>`.
- Subscribes to external audio position notifiers for animated seeks.
- Persists the current chapter to `UserSettings` with chapter-level dedupe.
- Runs continuous animation tickers for glowing borders and zoom transforms.

## Verification
- Run: `flutter test`
