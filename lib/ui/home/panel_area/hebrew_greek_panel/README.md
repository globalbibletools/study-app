# Hebrew Greek Panel

## Overview
Renders primary original language Scripture (Biblical Hebrew and Koine Greek) with custom leaf render box typography, interactive word popups, reading session completion checkboxes, audio highlight tracking, and bidirectional layout handling.

## Interface
- `panel.dart:HebrewGreekPanel`: Main container widget embedding infinite scroll view, pinch-to-zoom handlers, and chapter widgets.
- `panel.dart:HebrewGreekPanelState`: State class managing book visibility and zooming targets.
- `panel_manager.dart:HebrewGreekPanelManager`: ViewModel coordinating separate Hebrew and Greek font scales, reading mode flags, and settings persistence.
- `chapter.dart:VerseNumberTapNotification`: Notification dispatched when a verse number is tapped to trigger audio seeking.
- `chapter.dart:HebrewGreekChapter`: State-managed chapter view resolving word metrics, reading checkboxes, and word interaction popups.
- `chapter.dart:HebrewGreekChapterState`: State class managing chapter data fetching, verse offsets, and clipboard operations.
- `chapter_manager.dart:HebrewGreekChapterManager`: ViewModel loading original words from database, tracking read verses, and retrieving gloss popups.
- `chapter_manager.dart:VerseCheckboxNotifier`: Granular change notifier tracking read verse counts per verse.
- `text.dart:HebrewGreekText`: Leaf render object widget wrapping `RenderHebrewGreekText` for high-performance canvas text layout.
- `text.dart:RenderHebrewGreekText`: Custom render box handling multi-line word wrapping, bidirectional text (Hebrew RTL / Greek LTR), popup gloss positioning, and hit testing.
- `text.dart:HebrewGreekTextController`: Controller exposing verse rect coordinates and offset-to-verse mappings.
- `text.dart:WordPopup`: Data model holding popup gloss string, AI generated flag, and text direction.
- `text.dart:AsyncPopupWordProvider`: Function signature for asynchronously retrieving gloss details for a word.
- `text.dart:AsyncWordActionCallback`: Function signature for handling word long-press events.
- `text.dart:VerseAtOffsetCallback`: Function signature for mapping vertical Y coordinates to verse numbers.
- `text.dart:VerseLayoutBlock`: Model grouping contiguous words by verse for layout calculation.
- `text.dart:WordRenderer`: Rendering cache pairing a `HebrewGreekWord` with its measured `TextPainter` and layout `Rect`.
- `text.dart:VerseRenderer`: Rendering container holding verse numbers, checkbox metrics, and word renderers.

## Invariants
- Old Testament books (IDs 1–39) format as RTL Hebrew with `hebrewFontScale`, while New Testament books (IDs 40–66) format as LTR Greek with `greekFontScale`.
- Zoom gestures resolve the targeted book under the touch focal point and update only the corresponding language's scale.
- Words joined with Hebrew maqaph (`־`) omit inter-word whitespace.
- Reading count checkboxes cycle from 0 to `ReadingSessionManager.maximumReadCount` before resetting.

## Side Effects
- Loads Scripture words from `HebrewGreekDatabase.getChapter`.
- Retrieves localized word glosses via `GlossService.glossForId` and triggers downloads via `ResourceUIHelper.ensureResource`.
- Records verse reading completion and resets in `ReadingSessionManager`.
- Mutates font scale settings in `UserSettings`.
- Dispatches `VerseNumberTapNotification` to trigger audio player jumps.
- Copies verses to system clipboard via `Clipboard.setData`.
- Opens `WordDetailsDialog` modals.

## Verification
- Run: `flutter test`
