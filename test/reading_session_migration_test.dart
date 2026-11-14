import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('Reading Session Schema & Data Migration Tests', () {
    late Database db;

    // Helper to execute migration files the same way rs_database.dart does
    void executeSqlFile(Database db, String filePath) {
      final sql = File(filePath).readAsStringSync();
      final statements = sql
          .split(RegExp(r';\s*\n'))
          .where((s) => s.trim().isNotEmpty);

      for (final statement in statements) {
        db.execute(statement);
      }
    }

    // Helper to fast-forward a fresh v1 database through the migration
    // chain up to (and including) a given schema version file.
    void upgradeTo(Database db, int version) {
      for (int v = 2; v <= version; v++) {
        executeSqlFile(db, 'assets/schemas/reading_session_$v.sql');
      }
    }

    // Helper to create Schema Version 1
    void createSchemaV1(Database db) {
      db.execute('''
CREATE TABLE rs_daily_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rs_date DATE NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    verses INT NOT NULL
);

CREATE TABLE rs_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rs_daily_log_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    date_time TIMESTAMP NOT NULL,
    FOREIGN KEY (rs_daily_log_id) REFERENCES rs_daily_log(id)
);

CREATE TABLE rs_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type VARCHAR(1) NOT NULL,
    stats_date DATE NOT NULL,
    rs_seconds INT NOT NULL,
    rs_verses INT NOT NULL,
    goal_reached INT NOT NULL
);

CREATE UNIQUE INDEX hash_type_date ON rs_stats(type, stats_date);

CREATE TABLE rs_book_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id INT NOT NULL,
    chapter INT NOT NULL,
    verse INT NOT NULL,
    chapters_read INT NOT NULL,
    updated_at DATETIME NOT NULL
);

CREATE UNIQUE INDEX hash_rs_book_progress ON rs_book_progress(book_id);
''');
    }

    setUp(() {
      db = sqlite3.openInMemory();
    });

    tearDown(() {
      db.close();
    });

    test(
      'upgrades seamlessly from Schema 1 -> 2 -> 3 -> 4 -> 5 -> 6 preserving all progress',
      () {
        // 1. Initialize with Schema 1
        createSchemaV1(db);

        // Insert representative user reading progress in Schema 1
        final dateStr = '2026-05-01';
        final startStr = '2026-05-01T10:00:00.000';
        final endStr = '2026-05-01T10:15:30.000';
        final updatedAtGenesis = '2026-05-01T10:15:30.000';
        final updatedAtMatthew = '2026-05-02T11:00:00.000';

        db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses)
VALUES (1, '$dateStr', '$startStr', '$endStr', 25);

INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time)
VALUES
  (1, 1, 1, 1, 1, '$startStr'),
  (2, 1, 1, 1, 2, '$startStr'),
  (3, 1, 1, 1, 3, '$startStr'),
  (4, 1, 40, 1, 1, '$startStr');

INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached)
VALUES (1, 'D', '$dateStr', 930, 25, 1);

INSERT INTO rs_book_progress (id, book_id, chapter, verse, chapters_read, updated_at)
VALUES
  (1, 1, 1, 4, 0, '$updatedAtGenesis'),
  (2, 40, 1, 2, 0, '$updatedAtMatthew');
''');

        // 2. Run migration 2 (reading_session_2.sql)
        executeSqlFile(db, 'assets/schemas/reading_session_2.sql');

        // Verify v2 added verses_read and computed it correctly
        final v2Progress = db.select(
          'SELECT id, book_id, chapters_read, verses_read, updated_at FROM rs_book_progress ORDER BY book_id',
        );
        expect(v2Progress.length, 2);
        expect(v2Progress[0]['book_id'], 1);
        expect(v2Progress[0]['verses_read'], 3); // 3 verses read in Genesis
        expect(v2Progress[0]['updated_at'], updatedAtGenesis);
        expect(v2Progress[1]['book_id'], 40);
        expect(v2Progress[1]['verses_read'], 1); // 1 verse read in Matthew
        expect(v2Progress[1]['updated_at'], updatedAtMatthew);

        // In v2, ALTER TABLE ADD COLUMN placed verses_read at column index 7 (after updated_at)
        final v2Columns = db.select("PRAGMA table_info(rs_book_progress);");
        final colNames = v2Columns.map((r) => r['name']).toList();
        expect(
          colNames.indexOf('updated_at'),
          lessThan(colNames.indexOf('verses_read')),
        );

        // 3. Run migration 3 (reading_session_3.sql)
        executeSqlFile(db, 'assets/schemas/reading_session_3.sql');

        // Verify reading plans were created
        final plans = db.select('SELECT id, plan_name FROM reading_plan');
        expect(plans.length, 1);
        expect(plans[0]['id'], 1);
        expect(plans[0]['plan_name'], 'Whole Bible');

        final planBooks = db.select(
          'SELECT COUNT(*) AS count FROM reading_plan_book WHERE reading_plan_id = 1',
        );
        expect(planBooks.first['count'], 66);

        // Verify rs_daily_log migrated to reading_plan_id = 1
        final dailyLogs = db.select(
          'SELECT id, rs_date, verses, reading_plan_id FROM rs_daily_log',
        );
        expect(dailyLogs.length, 1);
        expect(dailyLogs[0]['verses'], 25);
        expect(dailyLogs[0]['reading_plan_id'], 1);

        // Verify rs_log migrated to reading_plan_id = 1
        final logs = db.select(
          'SELECT id, book_id, verse, reading_plan_id FROM rs_log',
        );
        expect(logs.length, 4);
        expect(logs[0]['reading_plan_id'], 1);

        // Verify rs_stats migrated to reading_plan_id = 1
        final stats = db.select(
          'SELECT id, type, rs_seconds, rs_verses, reading_plan_id FROM rs_stats',
        );
        expect(stats.length, 1);
        expect(stats[0]['rs_verses'], 25);
        expect(stats[0]['reading_plan_id'], 1);

        // Verify rs_book_progress has correct column types and values (explicit names prevented any swap!)
        final v3Progress = db.select(
          'SELECT id, book_id, chapter, verse, chapters_read, verses_read, updated_at, reading_plan_id FROM rs_book_progress ORDER BY book_id',
        );
        expect(v3Progress.length, 2);

        // Genesis
        expect(v3Progress[0]['book_id'], 1);
        expect(v3Progress[0]['verses_read'], 3);
        expect(v3Progress[0]['updated_at'], updatedAtGenesis);
        expect(v3Progress[0]['reading_plan_id'], 1);

        // Matthew
        expect(v3Progress[1]['book_id'], 40);
        expect(v3Progress[1]['verses_read'], 1);
        expect(v3Progress[1]['updated_at'], updatedAtMatthew);
        expect(v3Progress[1]['reading_plan_id'], 1);

        // Verify typeof columns in SQLite are correctly integer and text
        final genesisTypes = db.select(
          "SELECT typeof(verses_read) AS v_type, typeof(updated_at) AS u_type FROM rs_book_progress WHERE book_id = 1;",
        );
        expect(genesisTypes.first['v_type'], 'integer');
        expect(genesisTypes.first['u_type'], 'text');

        db.execute('''
INSERT INTO rs_log (rs_daily_log_id, book_id, chapter, verse, date_time, reading_plan_id)
VALUES (1, 1, 1, 1, '2026-05-03T09:00:00.000', 1);

DELETE FROM reading_plan_book WHERE reading_plan_id = 1 AND book_id = 40;
''');

        executeSqlFile(db, 'assets/schemas/reading_session_4.sql');

        final verseState = db.select(
          'SELECT reading_plan_id, book_id, chapter, verse, read_count, last_read '
          'FROM rs_verse_state ORDER BY book_id, chapter, verse',
        );
        expect(verseState.length, 4);

        final genesis11 = verseState.firstWhere(
          (r) => r['book_id'] == 1 && r['verse'] == 1,
        );
        expect(genesis11['reading_plan_id'], 1);
        expect(genesis11['chapter'], 1);
        expect(genesis11['read_count'], 2);
        expect(genesis11['last_read'], '2026-05-03T09:00:00.000');

        final genesis12 = verseState.firstWhere(
          (r) => r['book_id'] == 1 && r['verse'] == 2,
        );
        expect(genesis12['read_count'], 1);
        expect(genesis12['last_read'], startStr);

        final genesis13 = verseState.firstWhere(
          (r) => r['book_id'] == 1 && r['verse'] == 3,
        );
        expect(genesis13['read_count'], 1);

        final matthew11 = verseState.firstWhere(
          (r) => r['book_id'] == 40 && r['verse'] == 1,
        );
        expect(matthew11['read_count'], 1);
        expect(matthew11['last_read'], startStr);

        expect(
          () => db.execute(
            "INSERT INTO rs_verse_state (reading_plan_id, book_id, chapter, verse) "
            "VALUES (1, 1, 1, 1);",
          ),
          throwsA(isA<SqliteException>()),
        );

        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rs_book_progress'",
          ),
          isEmpty,
        );
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'hash_rs_book_progress'",
          ),
          isEmpty,
        );

        // 5. Run migration 5 (reading_session_5.sql): the consolidated
        // rs_session + rs_day_summary upgrade -- session rename, orphan
        // finalization, summary backfill, and rs_stats retirement in one
        // atomic step.
        executeSqlFile(db, 'assets/schemas/reading_session_5.sql');

        // rs_daily_log and rs_stats are gone; their data lives on in
        // rs_session and rs_day_summary.
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rs_daily_log'",
          ),
          isEmpty,
        );
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rs_stats'",
          ),
          isEmpty,
        );
        expect(
          db.select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'hash_type_date'",
          ),
          isEmpty,
        );

        final sessions = db.select(
          'SELECT id, rs_date, verses, reading_plan_id FROM rs_session',
        );
        expect(sessions.length, 1);
        expect(sessions[0]['id'], 1);
        expect(sessions[0]['verses'], 25);
        expect(sessions[0]['reading_plan_id'], 1);

        final logColumns = db
            .select('PRAGMA table_info(rs_log)')
            .map((r) => r['name'])
            .toList();
        expect(logColumns, contains('rs_session_id'));
        expect(logColumns, isNot(contains('rs_daily_log_id')));

        final migratedLogs = db.select(
          'SELECT id, rs_session_id, book_id, reading_plan_id FROM rs_log ORDER BY id',
        );
        expect(migratedLogs.length, 5);
        for (final log in migratedLogs) {
          expect(log['rs_session_id'], 1);
          expect(log['reading_plan_id'], 1);
        }

        // Totals are recomputed from the session, the flag comes from the
        // historical rs_stats row, and the goal snapshot comes from the plan.
        final summary = db.select(
          'SELECT reading_plan_id, rs_date, rs_seconds, rs_verses, goal_type, goal_value, goal_reached '
          'FROM rs_day_summary',
        );
        expect(summary.length, 1);
        expect(summary[0]['reading_plan_id'], 1);
        expect(summary[0]['rs_date'], '2026-05-01');
        expect(summary[0]['rs_seconds'], 930);
        expect(summary[0]['rs_verses'], 25);
        expect(summary[0]['goal_type'], 'M');
        expect(summary[0]['goal_value'], 10);
        expect(summary[0]['goal_reached'], 1);

        // 6. Run migration 6 (reading_session_6.sql): sessions gain an
        // accumulated read duration, backfilled from the old wall-clock
        // interval for already-closed sessions.
        executeSqlFile(db, 'assets/schemas/reading_session_6.sql');

        final sessionColumns = db
            .select('PRAGMA table_info(rs_session)')
            .map((r) => r['name'])
            .toList();
        expect(sessionColumns, contains('read_seconds'));

        final readTimes = db.select(
          'SELECT id, read_seconds FROM rs_session ORDER BY id',
        );
        expect(readTimes, hasLength(1));
        expect(readTimes[0]['read_seconds'], 930);

        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      },
    );

    test(
      'v5/v6 migration finalizes orphans, keeps empty sessions, renames sessions, backfills summaries and read times, and retires rs_stats',
      () {
        createSchemaV1(db);
        upgradeTo(db, 4);

        // Plan 1 is seeded by migration 3 with goal_type 'M' (minutes) and
        // goal_value 10, so the goal is reached at >= 600 seconds.
        db.execute(
          "UPDATE reading_plan SET goal_type = 'M', goal_value = 10 WHERE id = 1",
        );

        // Day 1: two closed sessions (600s + 330s = 930s, 25 verses),
        // stats row says goal_reached = 1.
        db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses, reading_plan_id)
VALUES
  (1, '2026-06-01T00:00:00.000', '2026-06-01T10:00:00.000', '2026-06-01T10:10:00.000', 15, 1),
  (2, '2026-06-01T00:00:00.000', '2026-06-01T11:00:00.000', '2026-06-01T11:05:30.000', 10, 1);
''');

        // Day 2: one closed session (300s, 5 verses) plus a killed session
        // (end_time null, 4 verses) whose last log row is at 09:50:00. The
        // stats row (flag 0) was computed under the old semantics, which
        // excluded the killed session -- the historical flag must win over
        // recomputation.
        db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses, reading_plan_id)
VALUES
  (3, '2026-06-02T00:00:00.000', '2026-06-02T09:00:00.000', '2026-06-02T09:05:00.000', 5, 1),
  (4, '2026-06-02T00:00:00.000', '2026-06-02T09:45:00.000', null, 4, 1);
''');
        db.execute('''
INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time, reading_plan_id)
VALUES
  (1, 4, 1, 1, 1, '2026-06-02T09:46:00.000', 1),
  (2, 4, 1, 1, 2, '2026-06-02T09:48:00.000', 1),
  (3, 4, 1, 1, 3, '2026-06-02T09:49:00.000', 1),
  (4, 4, 1, 1, 4, '2026-06-02T09:50:00.000', 1);
''');

        // Day 3: only a killed session (2 verses, logs 08:01 and 08:02) and
        // no stats row -- best-effort evaluation against the current goal.
        db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses, reading_plan_id)
VALUES (5, '2026-06-03T00:00:00.000', '2026-06-03T08:00:00.000', null, 2, 1);
''');
        db.execute('''
INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time, reading_plan_id)
VALUES
  (5, 5, 1, 1, 1, '2026-06-03T08:01:00.000', 1),
  (6, 5, 1, 1, 2, '2026-06-03T08:02:00.000', 1);
''');

        // Day 4: empty session (verses 0, end_time null, no logs) -- kept.
        db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses, reading_plan_id)
VALUES (6, '2026-06-04T00:00:00.000', '2026-06-04T07:00:00.000', null, 0, 1);
''');

        // Stats rows: daily flags for days 1 and 2, plus a monthly row that
        // nothing reads and must be ignored.
        db.execute('''
INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached, reading_plan_id)
VALUES
  (1, 'D', '2026-06-01T00:00:00.000', 930, 25, 1, 1),
  (2, 'D', '2026-06-02T00:00:00.000', 300, 5, 0, 1),
  (3, 'M', '2026-06-30T00:00:00.000', 9999, 99, 1, 1);
''');

        executeSqlFile(db, 'assets/schemas/reading_session_5.sql');

        // The old tables and index are gone.
        for (final name in ['rs_daily_log', 'rs_stats', 'hash_type_date']) {
          expect(
            db.select("SELECT name FROM sqlite_master WHERE name = '$name'"),
            isEmpty,
          );
        }

        // Killed sessions are finalized from their last log row; the empty
        // session is preserved with no end_time because it has no logs.
        final sessions = db.select(
          'SELECT id, end_time, verses FROM rs_session ORDER BY id',
        );
        expect(sessions.map((r) => r['id']).toList(), [1, 2, 3, 4, 5, 6]);
        expect(
          db
              .select('SELECT id FROM rs_session WHERE end_time IS NULL')
              .map((r) => r['id'])
              .toList(),
          [6],
        );
        expect(
          db
              .select('SELECT end_time FROM rs_session WHERE id = 4')
              .first['end_time'],
          '2026-06-02T09:50:00.000',
        );
        expect(
          db
              .select('SELECT end_time FROM rs_session WHERE id = 5')
              .first['end_time'],
          '2026-06-03T08:02:00.000',
        );

        // rs_log rows are preserved and re-pointed at rs_session.
        final logColumns = db
            .select('PRAGMA table_info(rs_log)')
            .map((r) => r['name'])
            .toList();
        expect(logColumns, contains('rs_session_id'));
        expect(logColumns, isNot(contains('rs_daily_log_id')));
        final logs = db.select(
          'SELECT id, rs_session_id FROM rs_log ORDER BY id',
        );
        expect(logs, hasLength(6));
        for (final log in logs) {
          expect(log['rs_session_id'], log['id'] <= 4 ? 4 : 5);
        }

        // Summaries: totals recomputed (finalized orphans now count), flags
        // from rs_stats where present, best-effort otherwise. The monthly
        // stats row creates no summary for 2026-06-30. The preserved empty
        // session contributes a zero-total row for 2026-06-04.
        final summaries = db.select(
          'SELECT rs_date, rs_seconds, rs_verses, goal_type, goal_value, goal_reached '
          'FROM rs_day_summary ORDER BY rs_date',
        );
        expect(summaries.map((r) => r['rs_date']).toList(), [
          '2026-06-01',
          '2026-06-02',
          '2026-06-03',
          '2026-06-04',
        ]);

        // Day 1: totals recomputed from sessions, flag from rs_stats.
        expect(summaries[0]['rs_seconds'], 930);
        expect(summaries[0]['rs_verses'], 25);
        expect(summaries[0]['goal_reached'], 1);
        expect(summaries[0]['goal_type'], 'M');
        expect(summaries[0]['goal_value'], 10);

        // Day 2: totals now include the finalized killed session (300s +
        // 300s = 600s, 9 verses) while the historical flag (0) survives --
        // recomputation would say reached, but the recorded flag wins.
        expect(summaries[1]['rs_seconds'], 600);
        expect(summaries[1]['rs_verses'], 9);
        expect(summaries[1]['goal_reached'], 0);

        // Day 3: brand new row from the finalized orphan, best-effort flag
        // against the current goal (120s < 600s).
        expect(summaries[2]['rs_seconds'], 120);
        expect(summaries[2]['rs_verses'], 2);
        expect(summaries[2]['goal_reached'], 0);

        // Day 4: the preserved empty session is all zeroes and not reached.
        expect(summaries[3]['rs_seconds'], 0);
        expect(summaries[3]['rs_verses'], 0);
        expect(summaries[3]['goal_reached'], 0);

        // The composite PK rejects a duplicate (plan, date) row.
        expect(
          () => db.execute(
            "INSERT INTO rs_day_summary (reading_plan_id, rs_date, rs_seconds, rs_verses, goal_reached) "
            "VALUES (1, '2026-06-01', 0, 0, 0)",
          ),
          throwsA(isA<SqliteException>()),
        );

        // v6 adds the accumulated foreground read time, backfilled from the
        // legacy wall-clock interval. The empty session stays at zero.
        executeSqlFile(db, 'assets/schemas/reading_session_6.sql');
        final readTimes = db.select(
          'SELECT id, read_seconds FROM rs_session ORDER BY id',
        );
        expect(readTimes.map((r) => r['read_seconds']).toList(), [
          600,
          330,
          300,
          300,
          120,
          0,
        ]);

        expect(db.select('PRAGMA foreign_key_check'), isEmpty);
      },
    );

    test(
      'explicit column mapping correctly migrates databases regardless of old table column order',
      () {
        // Simulate an old table that has verses_read BEFORE updated_at (as in fresh v2 installations)
        db.execute('''
CREATE TABLE rs_daily_log (id INTEGER PRIMARY KEY, rs_date DATE, start_time TIMESTAMP, end_time TIMESTAMP, verses INT);
CREATE TABLE rs_log (id INTEGER PRIMARY KEY, rs_daily_log_id INT, book_id INT, chapter INT, verse INT, date_time TIMESTAMP);
CREATE TABLE rs_stats (id INTEGER PRIMARY KEY, type VARCHAR(1), stats_date DATE, rs_seconds INT, rs_verses INT, goal_reached INT);
CREATE TABLE rs_book_progress (
    id INTEGER PRIMARY KEY,
    book_id INT,
    chapter INT,
    verse INT,
    chapters_read INT,
    verses_read INT,
    updated_at DATETIME
);
CREATE UNIQUE INDEX hash_type_date ON rs_stats(type, stats_date);
CREATE UNIQUE INDEX hash_rs_book_progress ON rs_book_progress(book_id);
''');

        final testDate = '2026-05-05T12:00:00.000';
        db.execute('''
INSERT INTO rs_book_progress (id, book_id, chapter, verse, chapters_read, verses_read, updated_at)
VALUES (1, 19, 23, 1, 22, 118, '$testDate');
''');

        // Run migration 3
        executeSqlFile(db, 'assets/schemas/reading_session_3.sql');

        final row = db
            .select('SELECT * FROM rs_book_progress WHERE book_id = 19;')
            .first;
        expect(row['verses_read'], 118);
        expect(row['updated_at'], testDate);
      },
    );

    test(
      'hash_type_date unique index allows stats for multiple reading plans on the same date',
      () {
        createSchemaV1(db);
        executeSqlFile(db, 'assets/schemas/reading_session_2.sql');
        executeSqlFile(db, 'assets/schemas/reading_session_3.sql');

        // Insert plan 1 stats
        db.execute('''
INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached, reading_plan_id)
VALUES (1, 'D', '2026-05-10', 600, 20, 1, 1);
''');

        // Create plan 2
        db.execute('''
INSERT INTO reading_plan (id, plan_name, created_at, last_read, collection_id, goal_type, goal_value, is_bookmarked)
VALUES (2, 'New Testament', '2026-05-10T08:00:00.000', null, 3, 'M', 15, 0);
''');

        // Insert plan 2 stats on the EXACT same date
        db.execute('''
INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached, reading_plan_id)
VALUES (2, 'D', '2026-05-10', 900, 30, 1, 2);
''');

        final stats = db.select(
          "SELECT * FROM rs_stats WHERE stats_date = '2026-05-10' ORDER BY reading_plan_id;",
        );
        expect(stats.length, 2);
        expect(stats[0]['reading_plan_id'], 1);
        expect(stats[1]['reading_plan_id'], 2);
      },
    );
  });
}
