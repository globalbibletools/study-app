# Lexicon Database Builder

## Overview
Compiles the Semantic Dictionaries of Biblical Hebrew (`sdbh.db`) and Biblical Greek (`sdbg.db`) into relational SQLite databases from UBS JSON lexicon sources, linking Strong's numbers to lemma definitions, grammatical parts of speech, and gloss senses.

## Interface
- `[database.dart:LexiconDatabase]`: Coordinates schema creation, JSON parsing, Strong's code cross-referencing, and meaning definitions insertion.
- `[database.dart:LexiconDatabase.input]`: Filesystem path to source UBS lexicon JSON file.
- `[database.dart:LexiconDatabase.output]`: File path for target SQLite database (`sdbh.db` or `sdbg.db`).
- `[database.dart:LexiconDatabase.init]`: Opens SQLite database connection and executes table creation DDL.
- `[database.dart:LexiconDatabase.deleteDatabase]`: Deletes existing target SQLite database file.
- `[database.dart:LexiconDatabase.populateTables]`: Ingests lexicon JSON, generates grammar lookup maps, inserts Strong's cross-references, and stores sanitized meaning senses.
- `[database.dart:LexiconDatabase.dispose]`: Terminates SQLite database connection.
- `[schema.dart:LexiconSchema]`: Schema definitions for `strongs`, `grammar`, and `meanings` tables, derived indices, and Strong's lookup query.
- `[schema.dart:LexiconSchema.lemmaIdOffset]`: Integer divisor (`1000000000`) for normalizing `MainId` into integer `lemma_id`.
- `[schema.dart:LexiconSchema.getMeaningsForStrongsQuery]`: Parameterized SQL query joining `meanings` and `strongs` on derived lemma ID.
- [data](./data/README.md): Upstream UBS dictionary resources and license documentation.

## Invariants
- `lemma_id` is derived from `MainId` using integer division `MainId ~/ 1000000000`.
- The meanings table links to `strongs` via the derived expression `(meanings.lex_id / 1000000000) = strongs.lemma_id`.
- Definition strings matching `'NO DATA YET'` are set to null, and prefixes `'= '` and `'≈ '` are stripped.
- Meanings are only stored if their gloss string is non-null and non-empty.

## Side Effects
- Synchronously removes existing database file specified by `output` upon `deleteDatabase()`.
- Reads source JSON dictionary files from disk via `File.readAsString`.
- Writes and indexes target SQLite database within transactional batches.
- Prints grammar counts, base form statistics, and error logs to standard output.

## Verification
- Run: `dart test`
