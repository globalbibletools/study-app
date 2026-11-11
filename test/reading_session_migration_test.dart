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

    test('upgrades seamlessly from Schema 1 -> 2 -> 3 -> 4 preserving all progress', () {
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
    });

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
