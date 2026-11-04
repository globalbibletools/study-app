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
- `scroll_sync_controller.dart:VerseHighlight`: Data class detailing active verse jumping and audio-driven verse highlighting.
- `scroll_sync_controller.dart:ScrollSyncController`: State coordinator keeping dual panels synchronized during user scrolls or audio playback while preventing feedback loops.
- `zoom_wrapper.dart:ZoomWrapper`: Pinch-to-zoom container providing focal-point-based scaling clamped between 0.5x and 5.0x.
- `zoom_wrapper.dart:CustomScaleGestureRecognizer`: Multi-touch scale recognizer rejecting single-pointer scroll conflicts.

## Invariants
- `ScrollSyncController` ignores scroll reports from passive panels when `_activeSource` is engaged, preventing infinite feedback recursion.
- `ZoomWrapper` clamps effective scaling strictly within range `[0.5, 5.0]`.
- In `TouchState.allowUnderSpotlight`, hit tests pass through exclusively within the inflated bounds of active cutouts.

## Side Effects
- Emits verse navigation events over broadcast `Stream<VerseHighlight>`.
- Subscribes to external audio position notifiers.
- Runs continuous animation tickers for glowing borders and zoom transforms.

## Verification
- Run: `flutter test`
