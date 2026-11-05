# File Service

## Overview
Manages local filesystem path resolution and storage directories for downloaded assets (Bibles, glosses, and audio files) rooted in the application documents directory.

## Interface
- [file_service.dart:FileService]: Service providing filesystem path resolution, directory scaffolding, and file deletion.
- [file_service.dart:FileService.getLocalPath]: Resolves absolute path given a `FileType` and relative path within the documents directory.
- [file_service.dart:FileService.checkFileExists]: Checks if a file of the specified `FileType` exists at the relative path.
- [file_service.dart:FileService.ensureDirectoryExists]: Recursively creates the parent directory of a target file path if missing.
- [file_service.dart:FileService.deleteFile]: Deletes a typed file if it exists on disk.
- [file_service.dart:FileService.directoryHasFiles]: Directory inspection placeholder helper.
- [file_service.dart:FileType]: Enumeration for root asset directories (`bible`, `audio`, `gloss`).

## Invariants
- Base directory paths strictly map from `FileType`:
  - `FileType.bible` -> `<appDocumentsDir>/bibles`
  - `FileType.gloss` -> `<appDocumentsDir>/glosses`
  - `FileType.audio` -> `<appDocumentsDir>/audio`

## Side Effects
- Queries the system platform channel for the application documents directory via `path_provider`.
- Performs disk I/O (creates directories, checks existence, and deletes files) via `dart:io`.

## Verification
- Run: `flutter test`
