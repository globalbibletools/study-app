# Bible Database Builder

## Overview
Parses raw USFM (Unified Scripture Format Markdown) scripture files into relational SQLite database instances, packing canonical verse coordinates into integers and preserving paragraph formatting markers.

## Interface
- `[database.dart:BibleDatabase]`: Manages SQLite database lifecycle, USFM marker parsing, reference packing, and batch line insertions.
- `[database.dart:BibleDatabase.databaseName]`: Translation database identifier string (e.g., `eng_bsb`).
- `[database.dart:BibleDatabase.init]`: Deletes existing SQLite file, opens connection, executes schema creation DDL, and prepares statements.
- `[database.dart:BibleDatabase.populateTable]`: Sequentially parses 66 canonical USFM files, strips inline tags/footnotes, resolves paragraph formats, and writes lines within a transaction.
- `[database.dart:BibleDatabase.beginTransaction]`: Initiates SQLite transaction block.
- `[database.dart:BibleDatabase.commitTransaction]`: Commits active SQLite transaction.
- `[database.dart:BibleDatabase.insertBreak]`: Inserts empty paragraph break line with format code `'b'`.
- `[database.dart:BibleDatabase.insertVerseLine]`: Packs coordinate integers into BBCCCVVV format and writes verse record.
- `[database.dart:BibleDatabase.dispose]`: Closes prepared SQLite statements and terminates database connection.
- `[database.dart:bibleBooks]`: Canonical ordered list of 66 USFM file paths (`gen.usfm` through `rev.usfm`).
- `[schema.dart:BibleSchema]`: Schema definitions for table `bible`, column identifiers (`_id`, `reference`, `text`, `format`), and SQL queries.

## Invariants
- `databaseName` must correspond directly to an existing input folder under `lib/src/bible/data/<databaseName>/`.
- Scriptural references must be packed into a 32-bit BBCCCVVV integer (`bookId * 1000000 + chapter * 1000 + verse`).
- USFM book headers (`\id`) must map to canonical book IDs (1 through 66).
- Empty text entries are rejected with an exception unless the format indicator is `'b'`.

## Side Effects
- Synchronously deletes pre-existing `$databaseName.db` file upon initialization.
- Asynchronously reads 66 USFM files from disk via `File.readAsLines`.
- Creates and writes SQLite database records in `$databaseName.db`.
- Prints processing logs and USFM inline marker telemetry to standard output.

## Verification
- Run: `dart test`
