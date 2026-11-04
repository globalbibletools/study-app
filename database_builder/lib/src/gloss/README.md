# Gloss Database Builder

## Overview
Compiles language-specific interlinear gloss SQLite databases (`<iso>.db`) from JSON word data, deduplicating gloss text strings into an indexed dictionary table and mapping them to biblical source word IDs.

## Interface
- `[database.dart:GlossDatabase]`: Controls database lifecycle, dictionary deduplication, and word gloss mapping.
- `[database.dart:GlossDatabase.languageIsoCode]`: ISO language identifier code specifying target DB and input directory.
- `[database.dart:GlossDatabase.init]`: Opens SQLite database connection, initializes schema tables, and creates prepared statements.
- `[database.dart:GlossDatabase.deleteDatabase]`: Deletes pre-existing SQLite database file from disk.
- `[database.dart:GlossDatabase.populateGlossTable]`: Scans source JSON files to populate foreign `text` table and populates `verses` gloss table with integer references.
- `[database.dart:GlossDatabase.dispose]`: Finalizes prepared statements and closes database connection.
- `[database.dart:Gloss]`: Data representation of an interlinear word gloss entry with `sourceId`, human `gloss`, and fallback `aiGloss`.
- `[database.dart:Gloss.fromJson]`: Factory constructing `Gloss` record from decoded JSON map.
- `[schema.dart:GlossSchema]`: Schema definitions for `verses` and `text` tables, column names (`word_id`, `text`, `is_ai`, `_id`), and SQL statements.

## Invariants
- Word identifiers must follow standard `BBCCCVVVWW` string encoding (e.g. `0100100101`).
- All distinct gloss phrases are assigned deterministic 1-based integer foreign keys sorted lexicographically.
- The `is_ai` flag must be set to 1 when human gloss is null and AI gloss is present; otherwise set to 0.
- Source files must reside at `../../data/<languageIsoCode>/<bookFileName>`.

## Side Effects
- Synchronously deletes existing `$languageIsoCode.db` file upon calling `deleteDatabase()`.
- Opens and writes SQLite database `$languageIsoCode.db` using batch transaction operations.
- Asynchronously reads canonical book JSON files from filesystem via `File.readAsString`.
- Prints processing milestones and word counts to standard output.

## Verification
- Run: `dart test`
