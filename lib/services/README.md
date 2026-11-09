# Services Package

## Overview
Root coordination layer for application services and infrastructure modules. Configures the centralized dependency injection service container via `GetIt`, wiring singletons for local storage, SQLite databases, network transfers, scripture engines, lexical reference tools, and reading session analytics.

## Interface
- [service_locator.dart:getIt]: Global `GetIt` service locator instance used across the app.
- [service_locator.dart:setupServiceLocator]: Configures and registers lazy, eager, and asynchronous service dependencies:
  - Registers `FileService`, `RemoteAssetService`, `HebrewGreekDatabase`, `GlossService`, `LexiconsDatabase`, `UserSettings`, `AppState`, `DownloadService`, `BibleService`, `ResourceService`, `ReadingSessionDatabase`, `ReadingPlanBackupService`, and `ReadingPlanService` as lazy singletons.
  - Registers `AppLogger` as an asynchronous singleton via `AppLogger.createDefault`.
  - Registers `ReadingSessionService` and `AppGuideManager` as eager singletons.
- [App Guide Service](./app_guide/README.md): Onboarding spotlight tours and dismissal tracking.
- [Audio Service](./audio/README.md): Chapter audio streaming, downloads, and verse timing synchronizations.
- [Bible Service](./bible/README.md): Active Bible database queries and USFM scripture line parsing.
- [Download Service](./download/README.md): Network transfers, cancellable downloads, and zip decompression.
- [File Service](./files/README.md): Filesystem paths and document directories for application assets.
- [Gloss Service](./gloss/README.md): Word-level biblical term translation lookups and AI-generation markers.
- [Hebrew and Greek Language Service](./hebrew_greek/README.md): Morphological analysis (Greek SRGNT, Hebrew tags) and original text searches.
- [Lexicon Service](./lexicon/README.md): Hebrew and Greek semantic dictionaries for Strong's concordance codes.
- [Logging Service](./logging/README.md): Daily structured JSONL file logging and developer console output.
- [Reading Session Service](./reading_session/README.md): Scripture reading session timers, goals, statistics, and SQLite backups.
- [Resource Management Service](./resources/README.md): Remote asset manifests, metadata tracking, package downloads, and updates.
- [User Settings Service](./settings/README.md): User preferences, typography scaling, and settings migrations.

## Invariants
- `setupServiceLocator()` must be called during application startup before accessing any service via `getIt<T>()`.
- `AppLogger` is registered asynchronously (`registerSingletonAsync`); dependent services must handle initial startup timing or await locator readiness.

## Side Effects
- Mutates global dependency injection container state in `GetIt`.
- Initializes default asynchronous log file directory creation during locator setup.

## Verification
- Run: `flutter test`
