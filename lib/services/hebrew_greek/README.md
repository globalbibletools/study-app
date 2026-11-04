# Hebrew and Greek Language Service

## Overview
Manages the bundled original-language Scripture database (`hebrew_greek.db`), providing morphology decoding for Greek (SRGNT 8-character encoding) and Hebrew (hyphenated feature strings), concordance searches by Strong's codes, and multi-word lemma/normalized text search queries.

## Interface
- [database.dart:HebrewGreekDatabase]: SQLite manager handling database deployment, migration from assets, and lexical queries.
- [database.dart:HebrewGreekDatabase.init]: Ensures the database file exists in local application storage, copying from assets or updating if the schema version changed.
- [database.dart:HebrewGreekDatabase.getChapter]: Retrieves all `HebrewGreekWord` instances for a book and chapter.
- [database.dart:HebrewGreekDatabase.getWordForId]: Finds a specific word record by its unique ID.
- [database.dart:HebrewGreekDatabase.getStrongsAndGrammar]: Resolves the Strong's number and raw grammar string for a given word ID.
- [database.dart:HebrewGreekDatabase.allVersesForStrongsCode]: Returns distinct `Reference` records for verses containing the given Strong's number.
- [database.dart:HebrewGreekDatabase.strongsCodeRoot]: Returns the lemma root string for a Strong's code.
- [database.dart:HebrewGreekDatabase.wordsForVerse]: Returns words belonging to a verse, optionally joining Strong's codes.
- [database.dart:HebrewGreekDatabase.getWordsStartingWith]: Prefix query returning distinct normalized words.
- [database.dart:HebrewGreekDatabase.searchVersesByNormalizedWords]: Conjunctive search finding verses containing all supplied normalized words.
- [database.dart:HebrewGreekDatabase.searchExactMatchNoPunctuation]: Matches verses containing an exact word ignoring punctuation.
- [srgnt_grammar.dart:parseSrgntGrammar]: Decodes 8-character SRGNT Greek morphology strings into human-readable descriptions.
- [hebrew_grammar.dart:parseHebrewGrammar]: Expands hyphen-separated Hebrew morphology codes (stems, conjugations, pronominal suffixes) into readable text.

## Invariants
- Database is version-checked against `HebrewGreekSchema.databaseVersion`. Outdated or missing databases are replaced from `assets/databases/hebrew_greek.db`.
- Verse ID prefix format is 8 digits: `${bookId(2)}${chapter(3)}${verse(3)}`.
- Greek grammar codes strictly match the 8-character pattern: `^[NVAESRCDPTI][IMSONP.][PIFAELU.][AMP.][123.][NVAGD.][MFN.][SP.]$`.

## Side Effects
- Copies binary database assets using `rootBundle`.
- Deletes and writes SQLite database files on disk via `sqflite`.

## Verification
- Run: `flutter test`
