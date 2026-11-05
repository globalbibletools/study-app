# Home

## Overview
Primary study screen orchestrating the Scripture reading workspace, app bar navigation, audio player bottom sheet, split translation panels, on-screen numerical keypad, and guided onboarding spotlights.

## Interface
- `home.dart:HomeScreen`: Root stateful widget hosting the scaffold, app bar, navigation drawer, reading panels, audio player, keypad, and spotlight guide overlay.
- `floating_return_pill.dart:FloatingReturnPill`: Floating pill widget displaying the active occurrence search lemma, return arrow to reopen occurrences, and a close button (`✕`) to dismiss search context.
- `word_study_overlay_layer.dart:WordStudyOverlayLayer`: Live Offstage overlay layer managing the nested Navigator for WordDetailsDialog and SimilarVersesPage, preserving memory state and scroll offset across context previews.
- `home_manager.dart:HomeManager`: Central state orchestrator coordinating references, panel anchors, split panel visibility, audio view model, search context pill lifecycle, word study session offstage toggling, and settings updates.
- `home_manager.dart:OccurrenceSearchContext`: Value record holding lemma details, search type, and origin anchor reference for word occurrences return navigation.
- `home_manager.dart:WordStudySession`: Active session tracking the word ID, text direction, original reading reference, and overlay visibility state.
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
- Active `OccurrenceSearchContext` persists while scrolling within the reader and is deterministically dismissed when the user explicitly changes book/chapter via `HomeAppBar` or taps the pill's close button (`✕`).
- Dismissing `WordDetailsDialog` after previewing context verses returns the reader to the original reference where the word was initially long-pressed. Tapping `✕` on the floating pill commits the current previewed location as the active reading position.

## Side Effects
- Enables and disables device screen wake lock via `WakelockPlus`.
- Persists active reference in `UserSettings.setCurrentBookChapter`.
- Listens to and mutates reading session and audio player state.
- Opens modal bottom sheets (`ReadingSheet`) and dialog alerts.

## Verification
- Run: `flutter test`
