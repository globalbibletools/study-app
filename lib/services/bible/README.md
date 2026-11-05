# Bible Service

## Overview
Coordinates read-only SQLite Bible text database connections and provides structured USFM scripture line retrieval by book and chapter. Automatically detects active translation changes from `UserSettings` and invalidates cached databases upon resource updates.

## Interface
- [bible_service.dart:BibleService]: Primary service managing the active Bible database lifecycle, script direction, and chapter extraction.
- [bible_service.dart:BibleService.currentBibleId]: Identifier of the currently opened Bible resource, or null if none loaded.
- [bible_service.dart:BibleService.currentTextDirection]: `ResourceLanguageTextDirection` (LTR or RTL) for the active Bible translation.
- [bible_service.dart:BibleService.addBibleResourceChangeListener]: Subscribes a listener to Bible resource updates.
- [bible_service.dart:BibleService.removeBibleResourceChangeListener]: Removes a subscribed listener.
- [bible_service.dart:BibleService.bibleExists]: Checks if a given Bible ID exists locally via `ResourceService`.
- [bible_service.dart:BibleService.getChapter]: Loads scripture lines (`List<UsfmLine>`) for a given book and chapter, invoking `onDatabaseMissing` on error.
- [bible_service.dart:BibleResourceChangeListener]: Function signature `void Function(String bibleId)` for Bible lifecycle notifications.
- [bible_database.dart:BibleDatabase]: Read-only SQLite adapter accessing `BibleSchema.bibleTextTable`.
- [bible_database.dart:BibleDatabase.open]: Asynchronously opens a read-only SQLite handle at the specified file path.
- [bible_database.dart:BibleDatabase.close]: Closes the underlying database connection.
- [bible_database.dart:BibleDatabase.getChapter]: Executes range queries across `BibleSchema.colReference` to return USFM formatted verses.
- [bible_database.dart:BibleDatabase.getVerses]: Batch queries multiple verse references in chunks of $\le 500$ parameters, filtering out section headers/non-scripture lines and joining multi-line poetry rows with single spaces.

## Invariants
- SQLite databases are opened exclusively with `readOnly: true`.
- Verse references are encoded as `bookId * 1000000 + chapter * 1000 + verse`. Range queries bound chapter verses between `chapter * 1000` and `(chapter + 1) * 1000`.
- Switching Bibles or receiving resource change events for the active Bible closes existing SQLite connections before reopening.

## Side Effects
- Interacts with local SQLite databases using `sqflite`.
- Subscribes to `ResourceType.bible` notifications in `ResourceService`.
- Reads user preferences from `UserSettings`.

## Verification
- Run: `flutter test`
