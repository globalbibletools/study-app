# Audio Service

## Overview
Coordinates audio playback resources and verse synchronization timing data for scripture chapters. Resolves local or remote streaming audio URLs and loads binary timing records (`timings.bin`) that map audio playback timestamps to specific verses.

## Interface
- [audio_service.dart:AudioService]: Core service managing audio speaker discovery, audio resource change subscriptions, and chapter timing resolution.
- [audio_service.dart:AudioService.addResourceChangeListener]: Adds an `AudioResourceChangeListener` callback.
- [audio_service.dart:AudioService.removeResourceChangeListener]: Removes an `AudioResourceChangeListener` callback.
- [audio_service.dart:AudioService.testamentForBookId]: Maps a 1-based Bible book index to `Testament.ot` or `Testament.nt`.
- [audio_service.dart:AudioService.buildResourceId]: Generates a canonical resource ID formatted as `{testament}/{source}/{bookKey}`.
- [audio_service.dart:AudioService.getSpeakers]: Queries available audio speakers for a given testament via `ResourceService`.
- [audio_service.dart:AudioService.getChapterData]: Fetches local file or remote streaming URL and corresponding verse timings for a book chapter.
- [audio_service.dart:AudioMissingException]: Exception thrown when chapter audio or timing binary data is missing locally and remotely.
- [audio_service.dart:Testament]: Enum defining testament divisions (`ot`, `nt`).
- [audio_service.dart:AudioResourceChangeListener]: Typedef for resource update notifications `void Function(String source, int bookId)`.
- [audio_service.dart:bookKeys]: Canonical 66 3-letter Bible book code array ordered from Genesis (`Gen`) to Revelation (`Rev`).
- [audio_timing.dart:AudioTiming]: Data model containing verse identifier, start timestamp in seconds, end timestamp in seconds, and derived `verseNumber`.
- [audio_timing_database.dart:AudioTimingDatabase]: In-memory binary parser and query engine for 11-byte fixed-stride chapter verse timing files.
- [audio_timing_database.dart:AudioTimingDatabase.openFile]: Factory to asynchronously load and parse a binary timing file from disk.
- [audio_timing_database.dart:AudioTimingDatabase.getTimingsForChapter]: Retrieves the list of `AudioTiming` objects for a 0-based chapter index.

## Invariants
- Audio timing binaries use an 11-byte stride per record: book (1 byte), chapter (1 byte), verse (1 byte), start centiseconds (4 bytes uint32), end centiseconds (4 bytes uint32).
- An end marker of `0xFFFFFFFF` denotes `double.infinity`.
- Books 1 through 39 map to Old Testament (`Testament.ot`); books 40 through 66 map to New Testament (`Testament.nt`).
- Changing the active audio speaker invalidates and clears the in-memory `_timingDbs` cache.

## Side Effects
- Reads files and inspects file system paths via `dart:io`.
- Checks existence and downloads binary timings from remote endpoints via `DownloadService`.
- Subscribes to resource change events through `ResourceService`.

## Verification
- Run: `flutter test`
