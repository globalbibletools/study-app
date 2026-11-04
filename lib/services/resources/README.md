# Resource Management Service

## Overview
Orchestrates remote asset discovery, manifest synchronizations (`manifest.jsonl`, `languages.jsonl`), local metadata caching in SQLite (`resources.db`), and asset downloads/unpacks for Bibles, gloss databases, and audio recordings. Tracks outdated package versions and resolves local storage paths and streaming URLs.

## Interface
- [resource_service.dart:ResourceService]: Central service coordinating resource manifest synchronizations, queries, downloads, installations, and deletions.
- [resource_service.dart:ResourceService.resourceConfigs]: Template configurations defining local and remote path structures per `ResourceType`.
- [resource_service.dart:ResourceService.outdatedResourceCounts]: `ValueNotifier<OutdatedResourceCounts>` tracking pending package updates.
- [resource_service.dart:ResourceService.addResourceTypeChangeListener]: Binds a listener to generic resource type mutations.
- [resource_service.dart:ResourceService.removeResourceTypeChangeListener]: Unbinds a type listener.
- [resource_service.dart:ResourceService.addResourceChangeListener]: Binds a listener for specific resource ID events.
- [resource_service.dart:ResourceService.removeResourceChangeListener]: Unbinds a resource ID listener.
- [resource_service.dart:ResourceService.getResourcesByType]: Queries available resources by category with optional language filtering.
- [resource_service.dart:ResourceService.getResourcesByPath]: Queries resources matching hierarchical path matcher segments.
- [resource_service.dart:ResourceService.getLanguages]: Returns all supported resource languages.
- [resource_service.dart:ResourceService.getLanguageForResource]: Resolves the language associated with a specific resource ID.
- [resource_service.dart:ResourceService.resourceExists]: Checks whether a resource is marked installed and exists on the filesystem.
- [resource_service.dart:ResourceService.getResourceLocalPath]: Resolves absolute filesystem path of an installed resource, throwing `ResourceMissingException` if absent.
- [resource_service.dart:ResourceService.getResourceStreamingUrl]: Resolves remote base streaming URL for streamable resources.
- [resource_service.dart:ResourceService.downloadResource]: Downloads and extracts a resource archive with progress updates and cancellation support.
- [resource_service.dart:ResourceService.deleteResource]: Deletes local resource files and marks uninstalled in SQLite database.
- [resource_service.dart:ResourceService.refresh]: Updates local database cache from remote resource and language manifests.
- [resource_service.dart:ResourceMissingException]: Exception thrown when a requested resource is uninstalled or missing from disk.
- [resource_service.dart:ResourceTypeConfig]: Template model defining URI patterns and local paths for a resource type.
- [resource_service.dart:ResourceChangeListener]: Typedef `void Function(ResourceType type)` for category update events.
- [resource_service.dart:ResourceTypeChangeListener]: Typedef `void Function(ResourceType type, String id)` for item update events.
- [resource.dart:Resource]: Domain model for a discoverable/installable resource or folder node.
- [resource.dart:ResourceType]: Enum defining resource categories (`gloss`, `bible`, `audio`).
- [resource.dart:ServerState]: Enum defining server status (`available`, `removed`).
- [resource.dart:InstallState]: Enum defining local state (`notInstalled`, `installed`).
- [resource.dart:InstallableDetails]: Packaging attributes (`sha256`, `size`, `url`, `serverUpdatedAt`, `localUpdatedAt`).
- [resource.dart:OutdatedResourceCounts]: Metrics model containing total count and map of outdated resources by type.
- [resource_language.dart:ResourceLanguage]: Data model describing language metadata (`code`, `name`, `textDirection`).
- [resource_language.dart:ResourceLanguageTextDirection]: Enum defining writing directions (`ltr`, `rtl`).
- [resource_database.dart:ResourceDatabase]: SQLite persistence layer managing `resources.db` schema and manifest batch synchronizations.
- [resource_database.dart:PathMatcher]: Segment matcher for path queries (`PathMatcher.any()`, `PathMatcher.exact()`).
- [remote_asset_service.dart:RemoteAssetService]: Resolves remote asset URLs from `ASSETS_BASE_URL` (defaulting to `https://assets.globalbibletools.com`) and generates audio asset structures.
- [remote_asset_service.dart:RemoteAsset]: Model defining asset transfer attributes (`remoteUrl`, `localRelativePath`, `fileType`, `isZip`).

## Invariants
- Manifest items must provide either all installable fields (`updatedAt`, `sha256`, `size`, `url`) as a leaf resource, or none as a group node.
- Outdated resource counts reflect installed resources where `server_updated_at` does not match `local_updated_at`.
- Host URL is determined by the compile-time environment variable `ASSETS_BASE_URL`, falling back to `https://assets.globalbibletools.com`.

## Side Effects
- Fetches remote manifests and zip archives over HTTP via `DownloadService`.
- Executes read, insert, update, and delete queries on SQLite `resources.db`.
- Creates and deletes files and directories on the local device filesystem via `dart:io`.

## Verification
- Run: `flutter test`
