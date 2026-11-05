# Database Builder Core Sources

## Overview
Houses core canonical Bible book metadata, identifier mappings, chapter index offsets, and specialized sub-builders for compiling SQLite databases for audio timings, scripture text, interlinear glosses, biblical languages, and lexicons.

## Interface
- `[book_id.dart:bookFileNames]`: Ordered list of 66 JSON filenames for canonical biblical books (`01-Gen.json` through `66-Rev.json`).
- `[book_id.dart:bookAbbreviationToIdMap]`: Map translating standard 3-letter USFM book abbreviations to 1-based canonical integer IDs (1..66).
- `[book_id.dart:bookIdToFullNameMap]`: Map resolving 1-based book IDs to canonical English book titles.
- `[book_id.dart:fullNameToBookIdMap]`: Map resolving English book names (including `'Psalm'` and `'Psalms'`) to canonical integer IDs.
- `[book_id.dart:bookIdToChapterIndexMap]`: Map providing cumulative chapter start index (0..1167) for each book across the 1,189 chapters in the Bible.
- `[book_id.dart:bookIdToChapterCountMap]`: Map providing the total chapter count for each canonical book ID.
- [audio](./audio/README.md): Builder for verse-synchronized audio timing databases.
- [bible](./bible/README.md): Builder for USFM Scripture text databases.
- [gloss](./gloss/README.md): Builder for interlinear gloss translations.
- [hebrew_greek](./hebrew_greek/README.md): Builder for Hebrew, Aramaic, and Greek original texts and morphology.
- [lexicon](./lexicon/README.md): Builder for Greek and Hebrew semantic dictionaries.

## Invariants
- Canonical book identifiers are 1-based contiguous integers from 1 (`GEN`) to 66 (`REV`).
- Cumulative chapter indices in `bookIdToChapterIndexMap` strictly match the running sum of preceding book chapter counts in `bookIdToChapterCountMap`.
- `bookFileNames` maintains exactly 66 elements in canonical order.

## Side Effects
- None

## Verification
- Run: `dart test`
