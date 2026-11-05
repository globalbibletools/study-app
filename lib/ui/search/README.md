# Search

## Overview
Provides original language Scripture search functionality, including a virtual Hebrew and Greek on-screen keyboard, autocomplete prefix candidate suggestions, final letter form corrections, and verse result concordance lists.

## Interface
- `search.dart:SearchPage`: Main search screen providing search input field, system/virtual keyboard toggling, and asynchronous verse results list.
- `keyboard.dart:HebrewGreekKeyboard`: In-app virtual keyboard for Biblical Hebrew and Greek alphabets with candidate word completion bar and language switching.
- `search_manager.dart:SearchPageManager`: Business logic manager handling prefix candidate queries, word replacement at cursor, verse concordance lookup, and search direction persistence.
- `search_manager.dart:VerseSearchResults`: Value container holding searched normalized tokens, matching verse references, and result count.

## Invariants
- Search input text direction defaults according to `isHebrewSearch` (`rtl` for Hebrew, `ltr` for Greek).
- Candidate completions in `HebrewGreekKeyboard` are limited to a maximum of 3 items.
- Inserting or replacing characters applies `fixFinalForms` to ensure correct Hebrew and Greek final letter glyphs.

## Side Effects
- Queries prefix matches and normalized word verses from `HebrewGreekDatabase`.
- Updates user preferences `isHebrewSearch` and `shouldUseSystemKeyboard` in `UserSettings`.
- Triggers device tactile feedback via `HapticFeedback.lightImpact`.

## Verification
- Run: `flutter test`
