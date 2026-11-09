# Reading Session Service

## Overview
Coordinates interactive Scripture reading sessions, real-time timer tracking, verse read auditing, daily goal calculations (minutes or verses), and book completion transitions. Manages local persistence and versioned JSON backup/restore using SQLite (`reading_session.db`). Reading plan views obtain progress and statistics through on-demand queries in `ReadingPlanService`; `ReadingSessionService` keeps only active-session state and verse-read caching.

## Interface
- [reading_session_service.dart:ReadingSessionService]: Central facade and manager coordinating timer lifecycle, verse read actions, goal fulfillment, and progress state.
- [reading_session_service.dart:ReadingSessionService.init]: Asynchronously initializes database connections and caches.
- [reading_session_service.dart:ReadingSessionService.readingModeNotifier]: `ValueNotifier<bool>` signaling whether an active session is running.
- [reading_session_service.dart:ReadingSessionService.displayGoalProgresNotifier]: `ValueNotifier<bool>` governing goal HUD visibility.
- [reading_session_service.dart:ReadingSessionService.totalVersesReadPerDay]: `ValueNotifier<int>` tracking verses completed today.
- [reading_session_service.dart:ReadingSessionService.totalSecondsReadPerDay]: `ValueNotifier<int>` tracking seconds elapsed today.
- [reading_session_service.dart:ReadingSessionService.totalSecondsReadPerSession]: `ValueNotifier<int>` tracking current session duration.
- [reading_session_service.dart:ReadingSessionService.goalReachedNotifier]: `ValueNotifier<bool>` triggering when the daily goal is accomplished.
- [reading_session_service.dart:ReadingSessionService.bookCompletedNotifier]: `ValueNotifier<(int, int)>` broadcasting book completion transitions `(completedBookId, nextBookId)`.
- [reading_session_service.dart:ReadingSessionService.startReadingSession]: Initiates or resumes a timed reading session for a plan, ending any active session for another plan first.
- [reading_session_service.dart:ReadingSessionService.endReadingSession]: Stops the active timer and persists or cleans up daily session logs.
- [reading_session_service.dart:ReadingSessionService.markVerseAsRead]: Records verse completion in `rs_log`, updates daily log totals, and triggers deterministic progress recomputation from SQLite when read for the first time.
- [reading_session_service.dart:ReadingSessionService.resetReadingCountForVerse]: Clears all `rs_log` entries for a verse in the active plan across sessions, adjusts the active daily log for current session reads, and recomputes book progress from SQLite.
- [reading_session_service.dart:ReadingSessionService.getBookProgressForActivePlan]: Asynchronously queries persisted book progress for a book ID in the currently active plan.
- [reading_session_service.dart:ReadingSessionService.resetForDatabaseRestore]: Clears active session state and caches before a backup restore.
- [reading_session_service.dart:ReadingSessionService.reloadAfterDatabaseRestore]: Reloads in-memory state after a backup restore.
- [rs_model.dart:DailyGoal]: Immutable structure representing goal target `(GoalType type, int value)`.
- [rs_model.dart:GoalType]: Enum for daily targets (`minutes`, `verses`).
- [rs_model.dart:StatsType]: Enum for statistical aggregation intervals (`weekly`, `monthly`).
- [rs_model.dart:ProgressType]: Enum for progress visualization (`byBook`, `bySection`).
- [reading_plan_service.dart:ReadingPlanService]: Stateless service for reading-plan metadata, book CRUD, and on-demand progress/statistics queries used by reading plan views.
- [reading_plan_service.dart:ReadingPlanService.ReadingPlanService]: Default constructor; resolves `ReadingSessionDatabase` through `getIt`.
- [reading_plan_service.dart:ReadingPlanService.withDatabase]: Constructor for supplying an explicit `ReadingSessionDatabase`, useful for tests or alternate databases.
- [reading_plan_service.dart:ReadingPlanService.getReadingPlans]: Loads all plans and their ordered books.
- [reading_plan_service.dart:ReadingPlanService.getReadingPlansWithProgress]: Loads all plans and computes chapter, verse, book completion, and latest-book progress from persisted book progress records.
- [reading_plan_service.dart:ReadingPlanService.getBooksProgress]: Queries and synthesizes progress records for all 66 Bible books for a plan.
- [reading_plan_service.dart:ReadingPlanService.getLatestBookProgress]: Queries the first incomplete book progress entry in plan order, or falls back to the most recently updated incomplete/completed book.
- [reading_plan_service.dart:ReadingPlanService.getMonthProgress]: Queries daily reading metrics for a calendar month with a 1-to-1 day mapping immune to daylight saving time fall-back shifts.
- [reading_plan_service.dart:ReadingPlanService.getDetailedProgressFor]: Reconstructs contiguous verse intervals read across sessions on a date.
- [reading_plan_service.dart:ReadingPlanService.getReadingPlanById]: Loads a single plan and its ordered books.
- [reading_plan_service.dart:ReadingPlanService.saveReadingPlan]: Creates or updates a plan, preserving retained book order and appending newly selected books in sorted order.
- [reading_plan_service.dart:ReadingPlanService.setReadingPlanBookmark]: Persists a plan bookmark state and returns the updated plan.
- [reading_plan_service.dart:ReadingPlanService.reorderReadingPlanBooks]: Persists book ordering and normalizes `ord` values.
- [reading_plan_service.dart:ReadingPlanService.deleteReadingPlan]: Deletes a plan and all dependent reading records.
- [reading_plan_backup_service.dart:ReadingPlanBackupService]: Stateless service for versioned JSON backup/restore, backup file discovery, and serialization.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.ReadingPlanBackupService]: Default constructor; resolves `ReadingSessionDatabase` through `getIt`.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.withDatabase]: Constructor for supplying an explicit `ReadingSessionDatabase`, useful for tests or alternate databases.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.createBackup]: Creates a timestamped backup file in the application documents backup directory.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.exportBackup]: Writes a backup payload to an explicit filesystem path.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.buildBackupBytes]: Serializes the current reading session tables into versioned JSON bytes.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.listBackups]: Lists saved backup files, newest first.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.restoreBackup]: Restores the database from a backup file path.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.restoreBackupBytes]: Restores the database from serialized backup bytes.
- [reading_plan_backup_service.dart:ReadingPlanBackupService.restoreBackupJson]: Parses versioned backup JSON and delegates table replacement to the database.
- [reading_plan_backup_service.dart:ReadingSessionBackupInfo]: Backup file metadata (`path`, `name`, `modifiedAt`, `sizeBytes`).
- [rs_database.dart:ReadingSessionDatabase]: SQLite persistence layer managing schema migrations, queries, and table-level backup snapshots.
- [rs_database.dart:ReadingSessionDatabase.init]: Opens database with migrations loaded from `assets/schemas/`.
- [rs_database.dart:ReadingSessionDatabase.getDistinctVersesReadPerChapter]: Queries SQLite for distinct verse counts per chapter in a book.
- [rs_database.dart:ReadingSessionDatabase.deleteRsLogsForVerse]: Deletes all `rs_log` rows for a specific verse in a reading plan.
- [rs_database.dart:ReadingSessionDatabase.saveReadingPlan]: Transactional plan creation or update with book sequence batching.
- [rs_database.dart:ReadingSessionDatabase.deleteReadingPlan]: Transactional cascade delete across `rs_log`, `rs_daily_log`, `rs_stats`, `rs_book_progress`, `reading_plan_book`, and `reading_plan`.
- [rs_database.dart:ReadingSessionDatabase.exportBackupTables]: Reads all backup-relevant tables into an in-memory snapshot.
- [rs_database.dart:ReadingSessionDatabase.restoreBackupTables]: Replaces all backup-relevant tables from a parsed payload inside a transaction, including v1 compatibility.
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
- Verse read cache in `ReadingSessionService` is scoped by `(readingPlanId, bookId, chapter)` tuples to prevent cross-plan collisions.
- `ReadingSessionService` keeps no book-progress or month-progress cache. Reading plan views fetch fresh progress and statistics through `ReadingPlanService` queries when needed.
- A book is marked complete if and only if `versesRead == BibleNavigation.getTotalVerseCount(bookId)`. Out-of-order reading is fully supported; completion reads current progress rows from SQLite, recomputes the cursor, and persists the result.
- Resume cursor always deterministically points to the lowest unread verse in the current chapter, or the lowest unread verse in the next incomplete chapter of that book, or the final verse upon 100% book completion.
- Plan deletion cascades across all dependent tables in a single SQLite transaction and resets any active session running on that plan.
- Sessions that record 0 verses read are deleted upon `endReadingSession()`, subtracting elapsed session seconds from daily statistics.
- Sessions spanning across midnight are split at the 23:59:59 boundary into consecutive daily session logs.
- Format version 1 backups are automatically adapted by assigning missing foreign keys to default plan ID 1.

## Side Effects
- Runs periodic 1-second `Timer` instances during active sessions.
- Writes, updates, and deletes records in `reading_session.db` using `sqflite`.
- Reads and writes backup files in the `backups` directory on local device storage.

## Verification
- Run: `flutter test`
