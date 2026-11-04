# Download Service

## Overview
Provides network download facilities for raw binary bytes, JSONL feeds, files, and zip archives. Supports cancellation tokens, progress reporting, HEAD-based existence checking, and atomic file and directory replacement via temporary staging paths.

## Interface
- [download.dart:DownloadService]: Core network manager handling file downloads, existence verification, and stream decompression.
- [download.dart:DownloadService.getBytes]: Fetches raw bytes from a URL into a `Uint8List`.
- [download.dart:DownloadService.checkExistence]: Executes an HTTP HEAD request returning boolean presence without fetching response payload.
- [download.dart:DownloadService.downloadFile]: Streams a remote URL into a `.part` staging file before renaming to target path.
- [download.dart:DownloadService.downloadZip]: Downloads and decompresses an archive into a timestamped temporary directory, then moves the single root entity to target path.
- [download.dart:DownloadService.getJsonl]: Streams and deserializes newline-delimited JSON into typed model lists.
- [download.dart:HttpNotFoundException]: Thrown when HTTP status is 404 Not Found.
- [cancel_token.dart:CancelToken]: Token pattern enabling cancellation signaling for asynchronous transfer tasks.
- [cancel_token.dart:CancelToken.isCancelled]: Flag indicating if cancellation was signaled.
- [cancel_token.dart:CancelToken.cancel]: Signals cancellation and notifies registered callbacks.
- [cancel_token.dart:CancelToken.addListener]: Binds a callback invoked upon cancellation.
- [cancel_token.dart:DownloadCanceledException]: Exception raised when an operation is cancelled via `CancelToken`.

## Invariants
- Direct file downloads stream to `${localPath}.part` before atomically renaming to `localPath`.
- Zip extraction validates that the archive contains exactly one top-level file or directory entity before replacing existing target files or directories.
- Staging files and extraction directories are deleted in `catch`/`finally` blocks upon failure or cancellation.

## Side Effects
- Performs HTTP GET and HEAD requests via `dart:io.HttpClient`.
- Modifies the local filesystem by creating temporary files and moving extracted directories.

## Verification
- Run: `flutter test`
