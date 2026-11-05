# Hebrew and Greek Database Builder

## Overview
Generates the core biblical morphological and lexical SQLite database (`hebrew_greek.db`), extracting Old Testament Hebrew/Aramaic words from JSON datasets and New Testament Greek words from SRGNT CSV data, indexing lexical lemmas, grammar tags, Strong's numbers, and normalized search strings.

## Interface
- `[normalization.dart:normalizeHebrewGreek]`: Decomposes characters to base NFD forms, strips non-essential characters, collapses spaces, normalizes final forms to standard letters, and lowercases Greek text.
- `[normalization.dart:removePunctuation]`: Removes Latin characters, Western punctuation, and Hebrew/Greek punctuation marks while retaining letters and diacritics.
- `[normalization.dart:fixFinalForms]`: Replaces interior final letters with standard forms and converts word-ending letters into appropriate final forms.
- `[schema.dart:HebrewGreekSchema]`: Defines database version (`databaseVersion = 13`), tables (`verses`, `words`, `text`, `grammar`, `strongs`), columns, indices, and prepared SQL statements.
- `[database.dart:HebrewGreekDatabase]`: Coordinates database construction, foreign table deduplication, batch insertion, and indexing for biblical original language texts.
- `[database.dart:HebrewGreekDatabase.init]`: Initializes database file, applies schema DDL, sets SQLite user_version PRAGMA, and initializes prepared statements.
- `[database.dart:HebrewGreekDatabase.deleteDatabase]`: Removes pre-existing `hebrew_greek.db` file from filesystem.
- `[database.dart:HebrewGreekDatabase.populateHebrewGreekTables]`: Ingests OT JSON and NT CSV files, builds frequency dictionaries, populates word tables, and creates database indices.
- `[database.dart:HebrewGreekDatabase.dispose]`: Closes prepared statements and database connection.
- `[database.dart:ForeignTableMaps]`: Record type `(Map<String, int>, Map<String, int>, Map<String, int>)` mapping unique text, grammar, and Strong's codes to foreign keys.
- `[database.dart:otBookFileNames]`: Slice of first 39 canonical book filenames for Old Testament processing.
- `[database.dart:srCsvPath]`: Relative filesystem path to New Testament SRGNT CSV data source.
- [strongs_data](./strongs_data/README.md): Strong's dictionary lookup data sources.

## Invariants
- Database `user_version` PRAGMA is explicitly set to `13`.
- `normalizeHebrewGreek` strictly strips any character outside Hebrew `\u05D0-\u05EA`, Greek `\u0391-\u03C9`, and spaces, and converts all final forms (`ךםןףץς` -> `כמנפצσ`).
- `words.word_id` is an opaque primary key string with `BBCCCVVVWW` structure, optionally including a `-NN` suffix for inserted New Testament tokens.
- `verses.verse_id` primary key conforms to 8-character `BBCCCVVV` string format.
- Old Testament source data requires 39 JSON files at `../../data/hbo+grc/`, and New Testament requires `lib/src/hebrew_greek/srgnt/sr.csv`.

## Side Effects
- Synchronously deletes existing `hebrew_greek.db` file upon `deleteDatabase()`.
- Reads OT JSON files, NT CSV files, and Strong's text definition files from disk.
- Writes and indexes `hebrew_greek.db` SQLite database using batch transactions.
- Writes word count statistics and frequency reports to standard output.

## Verification
- Run: `dart test`
