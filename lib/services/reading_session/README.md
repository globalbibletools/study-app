# Reading Session Service

## Overview
Coordinates interactive Scripture reading sessions, real-time timer tracking, verse read auditing, daily goal calculations (minutes or verses), and aggregated reading analytics. Manages local persistence and versioned JSON backup/restore using SQLite (`reading_session.db`).

## Interface
- [rs_manager.dart:ReadingSessionManager]: Central manager coordinating timer lifecycle, verse read actions, goal fulfillment, and progress state.
- [rs_manager.dart:ReadingSessionManager.init]: Asynchronously initializes database connections and caches.
- [rs_manager.dart:ReadingSessionManager.readingModeNotifier]: `ValueNotifier<bool>` signaling whether an active session is running.
- [rs_manager.dart:ReadingSessionManager.displayGoalProgresNotifier]: `ValueNotifier<bool>` governing goal HUD visibility.
- [rs_manager.dart:ReadingSessionManager.totalVersesReadPerDay]: `ValueNotifier<int>` tracking verses completed today.
- [rs_manager.dart:ReadingSessionManager.totalSecondsReadPerDay]: `ValueNotifier<int>` tracking seconds elapsed today.
- [rs_manager.dart:ReadingSessionManager.totalSecondsReadPerSession]: `ValueNotifier<int>` tracking current session duration.
- [rs_manager.dart:ReadingSessionManager.goalReachedNotifier]: `ValueNotifier<bool>` triggering when the daily goal is accomplished.
- [rs_manager.dart:ReadingSessionManager.bookCompletedNotifier]: `ValueNotifier<(int, int)>` broadcasting chapter and book completion transitions.
- [rs_manager.dart:ReadingSessionManager.startReadingSession]: Initiates a timed reading session for a plan.
- [rs_manager.dart:ReadingSessionManager.endReadingSession]: Stops the active timer and persists or cleans up daily session logs.
- [rs_manager.dart:ReadingSessionManager.markVerseAsRead]: Records verse completion, updates progress pointers, and recalculates daily goals.
- [rs_manager.dart:ReadingSessionManager.resetReadingCountForVerse]: Decrements verse reading count and reverts book progress if zeroed.
- [rs_manager.dart:ReadingSessionManager.loadBooksProgress]: Retrieves or synthesizes progress records for all 66 Bible books.
- [rs_manager.dart:ReadingSessionManager.getLatestBookProgress]: Returns the most recently updated book progress entry.
- [rs_manager.dart:ReadingSessionManager.loadMonthProgress]: Loads daily reading metrics for calendar grid displays.
- [rs_manager.dart:ReadingSessionManager.getDetailedProgressFor]: Reconstructs contiguous verse intervals read across sessions on a date.
- [rs_manager.dart:ReadingSessionManager.createBackup]: Creates a versioned JSON backup of reading plans, logs, and statistics.
- [rs_manager.dart:ReadingSessionManager.restoreBackup]: Restores database tables from a backup file path.
- [rs_manager.dart:DailyGoal]: Immutable structure representing goal target `(GoalType type, int value)`.
- [rs_manager.dart:GoalType]: Enum for daily targets (`minutes`, `verses`).
- [rs_manager.dart:StatsType]: Enum for statistical aggregation intervals (`weekly`, `monthly`).
- [rs_manager.dart:ProgressType]: Enum for progress visualization (`byBook`, `bySection`).
- [rs_database.dart:ReadingSessionDatabase]: SQLite persistence layer managing schema migrations, queries, and JSON backup/restore.
- [rs_database.dart:ReadingSessionDatabase.init]: Opens database with migrations loaded from `assets/schemas/`.
- [rs_database.dart:ReadingSessionDatabase.createBackup]: Serializes tables into JSON backup files.
- [rs_database.dart:ReadingSessionDatabase.restoreBackup]: Ingests JSON backup payloads (versions 1 and 2) inside a transaction.
- [rs_database.dart:ReadingSessionBackupInfo]: Backup file metadata (`path`, `name`, `modifiedAt`, `sizeBytes`).
- [rs_model.dart:ReadingPlan]: Entity defining a reading plan schedule and target goals.
- [rs_model.dart:ReadingPlanBook]: Join entity binding books to a reading plan in ordered sequence.
- [rs_model.dart:ReadingPlanDetails]: Aggregate container joining reading plan metadata, book lists, and calculated progress counters.
- [rs_model.dart:RsDailyLog]: Daily reading session record.
- [rs_model.dart:RsLog]: Single verse reading event timestamp record.
- [rs_model.dart:RsStats]: Aggregated daily or monthly statistics record.
- [rs_model.dart:RsBookProgress]: Reading progress position and completion counters for a specific book.
- [rs_model.dart:DayProgress]: Calendar day presentation model.
- [rs_model.dart:DetailedProgess]: Contiguous range of read verses (`fromVerse` to `toVerse`).
- [rs_model.dart:Session]: Aggregated session model containing daily log and detailed progress spans.

## Invariants
- Database is version 3 with automated sequential schema upgrades executed from `assets/schemas/reading_session_<version>.sql`.
- Sessions that record 0 verses read are deleted upon `endReadingSession()`, subtracting elapsed session seconds from daily statistics.
- Sessions spanning across midnight are split at the 23:59:59 boundary into consecutive daily session logs.
- Format version 1 backups are automatically adapted by assigning missing foreign keys to default plan ID 1.

## Side Effects
- Runs periodic 1-second `Timer` instances during active sessions.
- Writes, updates, and deletes records in `reading_session.db` using `sqflite`.
- Reads and writes backup files in the `backups` directory on local device storage.

## Verification
- Run: `flutter test`
