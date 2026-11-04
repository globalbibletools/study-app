# Home

## Overview
Primary study screen orchestrating the Scripture reading workspace, app bar navigation, audio player bottom sheet, split translation panels, on-screen numerical keypad, and guided onboarding spotlights.

## Interface
- `home.dart:HomeScreen`: Root stateful widget hosting the scaffold, app bar, navigation drawer, reading panels, audio player, keypad, and spotlight guide overlay.
- `home_manager.dart:HomeManager`: Central state orchestrator coordinating references, panel anchors, split panel visibility, audio view model, and settings updates.
- [App Bar](./appbar/README.md): Top toolbar providing reference navigation, reading mode indicators, and route drawers.
- [Audio Player](./audio/README.md): Media player interface for streaming and looping synchronized chapter audio.
- [Home Common UI](./common/README.md): Spotlight cutouts, tutorial guide bubbles, and dual-panel scroll synchronization controllers.
- [Keypad](./keypad/README.md): Slide-up numerical entry pad for typing chapters and verses.
- [Panel Area](./panel_area/README.md): Container grouping original Hebrew/Greek and translation reading panels.
- [Reading Plan](./reading_plan/README.md): Bottom sheet managing reading plans, goals, and session history.
- [Word Details Dialog](./word_details_dialog/README.md): Lexicon and grammar inspection dialog for selected biblical words.

## Invariants
- `WakelockPlus` is kept enabled while `HomeScreen` is mounted and disabled when disposed.
- In single-panel mode, the secondary Bible translation panel remains hidden if no valid translation is selected.
- Tapping outside focused reference inputs automatically dismisses the numeric keypad.

## Side Effects
- Enables and disables device screen wake lock via `WakelockPlus`.
- Persists active reference in `UserSettings.setCurrentBookChapter`.
- Listens to and mutates reading session and audio player state.
- Opens modal bottom sheets (`ReadingSheet`) and dialog alerts.

## Verification
- Run: `flutter test`
