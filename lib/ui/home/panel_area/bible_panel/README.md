# Bible Panel

## Overview
Renders secondary Bible translations in an infinite-scrolling pane synchronized with the main original language panel, formatting USFM text lines according to layout settings and handling resource availability checks.

## Interface
- `bible_panel.dart:BiblePanel`: Stateful widget embedding infinite scroll view, pinch-to-zoom scaling, and chapter view lifecycle.
- `bible_panel.dart:BiblePanelState`: State class managing settings updates and font scale propagation.
- `bible_panel_manager.dart:BiblePanelManager`: ViewModel coordinating font scale and verse layout notifiers with user settings.
- `bible_chapter.dart:BibleChapter`: Widget formatting chapter USFM content into paragraphs or verse-per-line layouts with footnote dialog support.
- `bible_chapter_manager.dart:BibleChapterManager`: Manager querying scripture data from `BibleService` and tracking text direction.

## Invariants
- If Bible data is missing and resource download cannot be completed, `onResourceUnavailable` is invoked to dismiss the panel.
- Text direction (`ltr` or `rtl`) adapts dynamically to the active Bible resource language.
- Pinch-to-zoom updates persist scale values into `UserSettings.bibleFontScale`.

## Side Effects
- Retrieves chapter lines from `BibleService.getChapter`.
- Triggers resource downloading through `ResourceUIHelper.ensureResource`.
- Persists user preferences via `UserSettings.setBibleFontScale`.
- Displays modal footnote dialogs.

## Verification
- Run: `flutter test`
