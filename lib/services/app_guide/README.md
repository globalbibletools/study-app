# App Guide Service

## Overview
Coordinates onboarding guide spotlights and tooltips across the application (e.g., directing users to initiate reading sessions and mark verses as read). Tracks the bounding rectangles of target widgets in global screen space and manages persistent dismissal states.

## Interface
- [app_guide_manager.dart:AppGuideManager]: State manager coordinating guide presentation conditions and target spotlight boundaries.
- [app_guide_manager.dart:AppGuideManager.checkBoxSpotlightRect]: `ValueNotifier<Rect?>` for target bounding box of the reading checkbox.
- [app_guide_manager.dart:AppGuideManager.readingSessionButtonSpotlightRect]: `ValueNotifier<Rect?>` for target bounding box of the reading session button.
- [app_guide_manager.dart:AppGuideManager.readingCheckboxGuideDismissedNotifier]: `ValueNotifier<bool>` tracking transient dismissal of the checkbox guide.
- [app_guide_manager.dart:AppGuideManager.readingSessionGuideDismissedNotifier]: `ValueNotifier<bool>` tracking transient dismissal of the session guide.
- [app_guide_manager.dart:AppGuideManager.shouldShowReadingSessionGuide]: Getter indicating if reading session onboarding guide should be displayed.
- [app_guide_manager.dart:AppGuideManager.shouldShowReadingCheckboxGuide]: Getter indicating if reading checkbox guide should be displayed.
- [app_guide_manager.dart:AppGuideManager.dismissReadingCheckboxGuide]: Asynchronously marks checkbox guide dismissed in state and persistent settings.
- [app_guide_manager.dart:AppGuideManager.dismissReadingSessionGuide]: Asynchronously marks session guide dismissed in state and persistent settings.
- [app_guide_manager.dart:AppGuideManager.anyGuideShown]: Evaluates whether any guide overlay should be rendered.
- [app_guide_manager.dart:AppGuideManager.dispose]: Disposes managed `ValueNotifier` instances.
- [global_rect.dart:GlobalRectReporter]: Widget wrapper that listens to layout changes via post-frame callbacks and notifies listeners of global screen rectangle coordinates.

## Invariants
- Reading session guide only appears when reading mode is inactive and not previously seen or dismissed.
- Reading checkbox guide only appears when reading mode is active, the reading session guide has previously been seen, and the checkbox guide has not been dismissed.
- Rectangle change notifications are debounced by a 0.5-pixel threshold to prevent unnecessary rebuild cycles.

## Side Effects
- Persists dismissal flags to local storage through `UserSettings`.
- Registers post-frame layout callbacks with `WidgetsBinding.instance`.

## Verification
- Run: `flutter test`
