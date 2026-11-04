# Reference Chooser

## Overview
Provides interactive selector widgets in the app bar allowing users to navigate Scripture references by book, chapter, and verse using direct keyboard entry, autocomplete filtering, or vertical swipe gestures.

## Interface
- `reference_chooser.dart:ReferenceInputMode`: Enum defining the active editing target (`none`, `book`, `chapter`, `verse`).
- `reference_chooser.dart:ReferenceChooser`: Stateful orchestrator managing book, chapter, and verse selector widgets along with physical/virtual digit keyboard routing.
- `reference_chooser.dart:ReferenceChooserState`: State class managing focus transitions, digit validation, backspace behavior, and available digit recalculations.
- `reference_input_field.dart:ReferenceInputField`: Interactive numerical display with custom blinking cursor and hardware key listener.
- `swipeable_selector.dart:SwipeableSelectorButton`: Touch widget supporting vertical drag transitions with peek previews and boundary bounce animations.
- `number_selector.dart:NumberSelector`: Toggles between `ReferenceInputField` when active and `SwipeableSelectorButton` when inactive.
- `book_selector.dart:BookSelector`: Text input with floating autocomplete overlay and fuzzy normalization for selecting Bible books.

## Invariants
- Entered numerical chapters and verses cannot exceed the limits returned by `BibleNavigation.getChapterCount` and `BibleNavigation.getVerseCount`.
- Typing an input sequence that has no further valid digit suffixes automatically triggers submission to the next component.
- Bible book selections are strictly bounded within canonical IDs 1 through 66.
- A single matching book during search text normalization triggers immediate auto-selection.

## Side Effects
- Mounts and unmounts floating autocomplete overlays via `Overlay.of(context).insert`.
- Requests and releases keyboard focus using `FocusNode` and `FocusManager`.
- Runs ticker animations for cursor blinking, slide transitions, and elastic bounce effects.

## Verification
- Run: `flutter test`
