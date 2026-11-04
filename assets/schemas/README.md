# Schemas

## Overview
Provides SQLite DDL schemas, migration scripts, and seed data for the reading session tracking subsystem. These SQL files are bundled as Flutter assets and loaded sequentially by `rs_database.dart` to initialize and upgrade the local reading session database (`reading_session.db`).

## Interface
- [reading_session.sql:reading_plan]: Table tracking Bible reading plans, goal type, goal value, and bookmark status.
- [reading_session.sql:reading_plan_book]: Join table linking canonical book IDs to reading plans with ordering sequence.
- [reading_session.sql:rs_daily_log]: Table recording daily reading session intervals, total verses, and reading plan references.
- [reading_session.sql:rs_log]: Granular per-verse reading timestamp logs linked to daily sessions and reading plans.
- [reading_session.sql:rs_stats]: Table maintaining aggregated daily ('D') and monthly ('M') reading statistics.
- [reading_session.sql:hash_type_date]: Unique index on `(type, stats_date, reading_plan_id)` preventing duplicate date-scoped stats.
- [reading_session.sql:rs_book_progress]: Table tracking chapter and verse progress per book and reading plan.
- [reading_session.sql:hash_rs_book_progress]: Unique index on `(book_id, reading_plan_id)`.
- [reading_session_2.sql:rs_book_progress.verses_read]: Column addition and backfill script counting distinct read verses from `rs_log`.
- [reading_session_3.sql:reading_plan]: Rebuilds schema introducing `reading_plan` and `reading_plan_book` tables, foreign keys, and indexes.
- [reading_session_data.sql:reading_plan]: Standalone seed script populating default 'Whole Bible' `reading_plan` and 66 canonical `reading_plan_book` records.

## Invariants
- Schema statements must be semicolon-newline delimited (matching `;\s*\n`) to support statement extraction by the batch executor in `rs_database.dart`.
- Foreign key constraints link session logs, book progress, and stats records to `reading_plan(id)`.
- Rebuilding tables in migration scripts must disable foreign keys (`PRAGMA foreign_keys = OFF`) during intermediate table swaps and re-enable them (`PRAGMA foreign_keys = ON`) prior to completion.
- Unique constraints on `(type, stats_date, reading_plan_id)` and `(book_id, reading_plan_id)` must be preserved across migrations.

## Side Effects
- Creates, alters, and rebuilds SQLite tables and indexes in the local SQLite database.
- Inserts baseline seed records for the default 'Whole Bible' reading plan and canonical book mappings.

## Verification
- Run: `flutter test test/reading_session_migration_test.dart`
