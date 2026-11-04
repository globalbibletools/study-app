# Similar Verses

## Overview
Displays concordance lookup results for Scripture verses containing words that share the same Strong's root or exact lexical form as a selected biblical word.

## Interface
- `similar_verses_page.dart:SearchType`: Enum defining search mode (`root` for Strong's code root concordance, `exact` for unpunctuated surface form matches).
- `similar_verses_page.dart:SimilarVersesPage`: Page rendering search results with root header, segmented mode control, and lazy verse list.
- `similar_verse_manager.dart:SimilarVerseManager`: Manager querying verse references and constructing highlighted rich text spans.

## Invariants
- Word matching highlights occur by Strong's concordance identifier under `SearchType.root` or stripped punctuation string match under `SearchType.exact`.
- Hebrew words ending in maqaph (`־`) do not append trailing spaces.

## Side Effects
- Queries database records through `HebrewGreekDatabase` for Strong's roots, concordance references, and full verse text.

## Verification
- Run: `flutter test`
