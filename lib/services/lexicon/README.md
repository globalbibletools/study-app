# Lexicon Service

## Overview
Manages local SQLite databases for Hebrew (`sdbh.db`) and Greek (`sdbg.db`) lexicons, providing semantic dictionary definitions, short glosses, and grammatical remarks for Strong's concordance codes. Automatically sanitizes internal scripture and lemma markup references for display.

> **Developer Notes & Attribution**
> Data was extracted from:
> https://github.com/ubsicap/ubs-open-license/tree/main/dictionaries
>
> LICENSE: [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/)

## Interface
- [database.dart:LexiconsDatabase]: Core lexicon service managing SQLite handles for Hebrew and Greek semantic dictionaries.
- [database.dart:LexiconsDatabase.init]: Ensures both dictionary databases exist locally and are upgraded to the required schema version from asset bundles.
- [database.dart:LexiconsDatabase.getMeaningsForStrongs]: Queries lexicon definitions for a Strong's identifier, routing to Hebrew or Greek database by prefix.
- [database.dart:LexiconMeaning]: Data model containing lexical identifier (`lexId`), `lemma`, `grammar`, `definitionShort`, `comments`, and `glosses`.
- [database.dart:LexiconMeaning.lemmaId]: Computed property returning `lexId ~/ LexiconSchema.lemmaIdOffset`.
- [database.dart:LexiconMeaning.fromMap]: Factory deserializer parsing database rows and replacing custom markup tags (`{L:...}`, `{S:...}`, `{N:...}`).

## Invariants
- Strong's codes prefixed with `'H'` route to the Hebrew database (`sdbh.db`); all others (e.g. `'G'`) route to Greek (`sdbg.db`).
- Both lexicon databases enforce version 2; mismatched versions are recreated from `assets/databases/`.

## Side Effects
- Copies binary databases from Flutter asset `rootBundle` to local device storage.
- Deletes obsolete SQLite files and queries SQLite handles via `sqflite`.

## Verification
- Run: `flutter test`
