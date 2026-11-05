# Similar Verses

## Overview
Displays concordance lookup results for Scripture verses containing words that share the same Strong's root or exact lexical form as a selected biblical word. Supports in-place floating gloss lookups, multi-translation parallel Bible viewing, and one-tap reader context jumping with floating return navigation.

## Interface
- `similar_verses_page.dart:SearchType`: Enum defining search mode (`root` for Strong's code root concordance, `exact` for unpunctuated surface form matches).
- `similar_verses_page.dart:SimilarVersesPage`: Page rendering search results with root header, segmented mode control, parallel versions configuration action chip, scroll-restored verse list, and reference jumping.
- `similar_verse_manager.dart:SimilarVerseManager`: Manager querying concordance references, managing page-scoped parallel Bible SQLite connections, batch loading verse text, and caching parallel translations.
- `parallel_translations_sheet.dart:ParallelTranslationsSheet`: Modal bottom sheet allowing users to toggle installed Bible translations and download new translations from the resource catalog.
- `parallel_translations_sheet.dart:showParallelTranslationsSheet`: Helper function presenting `ParallelTranslationsSheet` within a draggable scrollable modal sheet.

## Invariants
- Word matching highlights occur by Strong's concordance identifier under `SearchType.root` or stripped punctuation string match under `SearchType.exact`.
- Hebrew words ending in maqaph (`־`) do not append trailing spaces.
- Parallel Bible SQLite database connections are scoped to the `SimilarVerseManager` page lifecycle and closed immediately upon `dispose()`.
- Parallel translations configuration persists across sessions via `UserSettings.occurrenceParallelBibles`.
- Tapping a reference header navigates to the Scripture reader, anchors an `OccurrenceSearchContext`, and mounts `FloatingReturnPill`.

## Side Effects
- Queries database records through `HebrewGreekDatabase` for Strong's roots, concordance references, and full verse text.
- Opens and closes secondary read-only translation SQLite databases via `BibleDatabase`.
- Downloads Bible resources via `ResourceUIHelper` / `ResourceService`.
- Mutates user configuration via `UserSettings.setOccurrenceParallelBibles`.
- Pushes navigation context onto `HomeManager.searchContextNotifier`.

## Verification
- Run: `flutter test test/ui/home/word_details_dialog/similar_verses/`
