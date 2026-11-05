# Gloss Service

## Overview
Provides word-level translation gloss lookups for biblical terms across configured language databases. Manages SQLite gloss database handles, resolves AI-generated gloss indicators, and handles language change invalidation.

## Interface
- [gloss_service.dart:GlossService]: Core service managing active gloss database connections and query dispatch.
- [gloss_service.dart:GlossService.glossesExists]: Checks if the gloss database for a language code exists locally.
- [gloss_service.dart:GlossService.glossForId]: Resolves `GlossResult` for a specific word ID using the preferred language from `UserSettings`.
- [gloss_database.dart:GlossResult]: Data model containing `gloss` text, `isAiGenerated` flag, and `textDirection`.
- [gloss_database.dart:GlossDatabase]: Read-only SQLite interface querying `GlossSchema.versesTable` and `GlossSchema.textTable`.
- [gloss_database.dart:GlossDatabase.open]: Asynchronously opens the SQLite database at a file path with `readOnly: true`.
- [gloss_database.dart:GlossDatabase.close]: Closes the active database connection.
- [gloss_database.dart:GlossDatabase.getGloss]: Performs relational join on word ID to fetch gloss text and AI-generation flag.

## Invariants
- Gloss SQLite databases are opened strictly in read-only mode (`readOnly: true`).
- AI attribution is determined by `is_ai == 1` in the verses table.
- A change in the configured gloss language or a resource notification matching the current language closes and purges the active database connection.

## Side Effects
- Queries SQLite database files via `sqflite`.
- Subscribes to `ResourceType.gloss` change notifications from `ResourceService`.

## Verification
- Run: `flutter test`
