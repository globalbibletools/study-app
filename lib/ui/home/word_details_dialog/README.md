# Word Details Dialog

## Overview
Provides a modal inspection dialog for individual Hebrew and Greek words, showing surface forms, interactive grammar tags with expansion popups, gloss translations with AI indicators, lexicon definitions, and navigation to concordance searches.

## Interface
- `word_details_dialog.dart:WordDetailsDialog`: Stateful dialog displaying word morphology, definitions, copy button, and font zoom wrapper.
- `dialog_manager.dart:WordDetailsDialogManager`: Change notifier orchestrating word lookups, grammar code expansions, lexicon queries, and font scale persistence.
- `dialog_manager.dart:WordDetails`: Value model holding word text, Strong's identifier, grammar tags, gloss string, AI generation flag, and RTL directionality.
- [Similar Verses](./similar_verses/README.md): Concordance view listing matching verses across Scripture.

## Invariants
- `WordDetails.isRtl` evaluates to true for Hebrew Strong's codes (`H...`) and false for Greek (`G...`).
- Pinch zoom scales body explanations, glosses, and lexicon meanings while keeping the primary word header at a constant base size.

## Side Effects
- Queries data across `HebrewGreekDatabase`, `GlossService`, and `LexiconsDatabase`.
- Updates `UserSettings.wordDetailsFontScale`.
- Writes selected word strings to system clipboard via `Clipboard.setData`.
- Launches `SimilarVersesPage` route and displays nested expansion dialogs.

## Verification
- Run: `flutter test`
