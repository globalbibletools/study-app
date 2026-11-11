import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<ReadingSessionDatabase> openDatabase(String name) async {
    final database = ReadingSessionDatabase(
      databaseName: name,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    return database;
  }

  Future<sqlite.Database> openRaw(String name) async {
    final path = p.join(await getDatabasesPath(), name);
    await Directory(p.dirname(path)).create(recursive: true);
    return sqlite.sqlite3.open(path);
  }

  int expectedVerseCountFor(Set<int> bookIds) {
    final inventory = createTestVerseInventory(bookIds: bookIds);
    return inventory.values.fold(0, (sum, verses) => sum + verses.length);
  }

  test('onCreate materializes every verse in the seeded plan', () async {
    final name = 'verse_state_create_test.db';
    final database = await openDatabase(name);
    addTearDown(database.dispose);

    final raw = await openRaw(name);
    addTearDown(raw.close);

    final allBookIds = {
      for (final key in createTestVerseInventory().keys) key.$1,
    };
    final expected = expectedVerseCountFor(allBookIds);

    expect(
      raw
          .select(
            'SELECT COUNT(*) AS count FROM rs_verse_state WHERE reading_plan_id = 1',
          )
          .first['count'],
      expected,
    );

    final genesis = raw
        .select(
          'SELECT read_count, last_read FROM rs_verse_state '
          'WHERE reading_plan_id = 1 AND book_id = 1 AND chapter = 1 AND verse = 1',
        )
        .single;
    expect(genesis['read_count'], 0);
    expect(genesis['last_read'], isNull);
  });

  test('upgrade to v4 backfills from rs_log and materializes zeros', () async {
    final name = 'verse_state_upgrade_test.db';
    final path = p.join(await getDatabasesPath(), name);
    await Directory(p.dirname(path)).create(recursive: true);
    await deleteDatabase(path);

    final raw = sqlite.sqlite3.open(path);
    raw.execute('''
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

INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses)
VALUES (1, '2026-05-01', '2026-05-01T10:00:00.000', '2026-05-01T10:10:00.000', 1);

INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time)
VALUES (1, 1, 63, 1, 1, '2026-05-01T10:05:00.000');
''');

    void executeSqlFile(String filePath) {
      final sql = File(filePath).readAsStringSync();
      for (final statement
          in sql.split(RegExp(r';\s*\n')).where((s) => s.trim().isNotEmpty)) {
        raw.execute(statement);
      }
    }

    executeSqlFile('assets/schemas/reading_session_2.sql');
    executeSqlFile('assets/schemas/reading_session_3.sql');

    raw.execute('''
DELETE FROM reading_plan_book
WHERE reading_plan_id = 1 AND book_id NOT IN (63, 64, 66);
PRAGMA user_version = 3;
''');
    raw.close();

    final database = ReadingSessionDatabase(
      databaseName: name,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    addTearDown(database.dispose);
    await database.init();

    final inspection = await openRaw(name);
    addTearDown(inspection.close);

    final expected = expectedVerseCountFor({63, 64, 66});
    expect(
      inspection
          .select(
            'SELECT COUNT(*) AS count FROM rs_verse_state WHERE reading_plan_id = 1',
          )
          .first['count'],
      expected,
    );

    final backfilled = inspection
        .select(
          'SELECT read_count, last_read FROM rs_verse_state '
          'WHERE reading_plan_id = 1 AND book_id = 63 AND chapter = 1 AND verse = 1',
        )
        .single;
    expect(backfilled['read_count'], 1);
    expect(backfilled['last_read'], '2026-05-01T10:05:00.000');

    final zero = inspection
        .select(
          'SELECT read_count, last_read FROM rs_verse_state '
          'WHERE reading_plan_id = 1 AND book_id = 63 AND chapter = 1 AND verse = 2',
        )
        .single;
    expect(zero['read_count'], 0);
    expect(zero['last_read'], isNull);
  });

  test(
    'saving a plan materializes newly added books and keeps removed rows',
    () async {
      final name = 'verse_state_save_test.db';
      final database = await openDatabase(name);
      addTearDown(database.dispose);

      final plan = await database.saveReadingPlan(
        planName: 'Materialization Test',
        collectionId: 1,
        goalType: 'verses',
        goalValue: 10,
        orderedBookIds: [63, 64],
      );

      final raw = await openRaw(name);
      addTearDown(raw.close);

      int countForPlan() =>
          raw.select(
                'SELECT COUNT(*) AS count FROM rs_verse_state '
                'WHERE reading_plan_id = ?',
                [plan.id],
              ).first['count']
              as int;

      expect(countForPlan(), expectedVerseCountFor({63, 64}));

      final details = await database.getReadingPlanById(plan.id!);
      await database.saveReadingPlan(
        existingPlan: details!.readingPlan,
        planName: 'Materialization Test',
        collectionId: 1,
        goalType: 'verses',
        goalValue: 10,
        orderedBookIds: [63, 64, 66],
      );
      expect(countForPlan(), expectedVerseCountFor({63, 64, 66}));

      final withAddedBook = await database.getReadingPlanById(plan.id!);
      await database.saveReadingPlan(
        existingPlan: withAddedBook!.readingPlan,
        planName: 'Materialization Test',
        collectionId: 1,
        goalType: 'verses',
        goalValue: 10,
        orderedBookIds: [63, 66],
      );

      expect(countForPlan(), expectedVerseCountFor({63, 64, 66}));
      expect(
        (await database.getReadingPlanBooks(plan.id!)).map((b) => b.bookId),
        [63, 66],
      );
    },
  );

  test('a plan book with no inventory ranges gets zero rows', () async {
    final name = 'verse_state_empty_book_test.db';
    final database = await openDatabase(name);
    addTearDown(database.dispose);

    final plan = await database.saveReadingPlan(
      planName: 'Empty Book Test',
      collectionId: 1,
      goalType: 'verses',
      goalValue: 10,
      orderedBookIds: [63, 67],
    );

    final raw = await openRaw(name);
    addTearDown(raw.close);

    expect(
      raw.select(
        'SELECT COUNT(*) AS count FROM rs_verse_state '
        'WHERE reading_plan_id = ? AND book_id = 63',
        [plan.id],
      ).first['count'],
      13,
    );
    expect(
      raw.select(
        'SELECT COUNT(*) AS count FROM rs_verse_state '
        'WHERE reading_plan_id = ? AND book_id = 67',
        [plan.id],
      ).first['count'],
      0,
    );
    expect(await database.isBookComplete(plan.id!, 67), isFalse);
    expect((await database.getBookStats(plan.id!))[67], isNull);
  });
}
