# Audio Database Builder

## Overview
Extracts, cleans, and indexes audio verse synchronization timestamps from CSV sources into the SQLite database `audio_timings.db` for verse-synchronized audio playback.

## Interface
- `[database.dart:AudioDatabase]`: Manages database lifecycle, CSV ingestion, timestamp validation, and batch transactions.
- `[database.dart:AudioDatabase.outputDbName]`: Constant file path for target database (`audio_timings.db`).
- `[database.dart:AudioDatabase.init]`: Removes existing database file, initializes SQLite connection, runs DDL, and prepares statements.
- `[database.dart:AudioDatabase.populateTable]`: Asynchronously parses CSV timings, normalizes overlapping boundaries, and executes batch inserts.
- `[database.dart:AudioDatabase.dispose]`: Finalizes prepared statements and closes SQLite database connection.
- `[database.dart:TimingRecord]`: Representation of a parsed verse timing entry with `verseId`, `recordingId`, `start`, and optional `end` timestamp.
- `[schema.dart:AudioSchema]`: Schema definitions, table names, indices, and prepared SQL queries for audio timings table.

## Invariants
- CSV inputs require a header row and at least 5 columns per data row (`id`, `verseId`, `recordingId`, `start`, `end`).
- Records must be sorted ascending by `recordingId` and `verseId` before boundary resolution.
- End timestamps that are null, less than or equal to `start`, or overlap the subsequent verse within the same chapter file (`verseId ~/ 1000`) are repaired by setting `end` to `next.start` (or null if last verse in chapter).

## Side Effects
- Synchronously deletes pre-existing `audio_timings.db` file on initialization.
- Asynchronously reads CSV files from disk via `File.readAsLines`.
- Opens and writes SQLite database `audio_timings.db` within database transactions.
- Writes diagnostic logs to standard output and `dart:developer:log`.

## Verification
- Run: `dart test`
