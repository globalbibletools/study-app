# Backup Restore

## Overview
Provides the UI page for backing up, exporting, importing, and restoring reading session databases and user history.

## Interface
- `backup_restore.dart:BackupRestorePage`: Stateful widget providing actions to create internal backups, export backup JSON files to external storage, import JSON backups, and restore previous snapshots.

## Invariants
- Action buttons and restore triggers are disabled while `_busy` is true.
- Restoring a backup snapshot requires explicit user confirmation via dialog prior to database mutation.

## Side Effects
- Invokes `ReadingSessionManager` to query, create, serialize, and restore reading session database snapshots.
- Invokes `PackageInfo.fromPlatform` to retrieve app version metadata.
- Opens system file picker dialogs to save or pick JSON backup files via `FilePicker`.
- Displays `SnackBar` feedback messages and shows alert dialogs.

## Verification
- Run: `flutter test`
