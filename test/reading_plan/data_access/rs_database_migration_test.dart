import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/day_summary_repository.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/data_access/verse_state_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

typedef _BookStatsSnapshot = ({
  int totalVerses,
  int versesRead,
  DateTime? lastRead,
  Reference? resumePosition,
});

_BookStatsSnapshot _snapshotOf(BookStats stats) => (
  totalVerses: stats.totalVerses,
  versesRead: stats.versesRead,
  lastRead: stats.lastRead,
  resumePosition: stats.resumePosition,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String databasePath;
  ReadingSessionDatabase? database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rs_migration_test_');
    databasePath = p.join(tempDir.path, 'reading_session.db');
  });

  tearDown(() async {
    database?.dispose();
    database = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> openReadingDatabase({String? legacyDailyGoal}) async {
    database = ReadingSessionDatabase.withDependencies(
      databasePath: databasePath,
      legacyDailyGoal: legacyDailyGoal,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database!.init();
  }

  Future<List<Map<String, Object?>>> query(String sql) {
    return database!.unitOfWork((uow) => uow.executor.rawQuery(sql));
  }

  Future<void> expectV9Schema() async {
    expect((await query('PRAGMA user_version')).single['user_version'], 9);

    final tableNames = (await query(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();
    expect(
      tableNames,
      containsAll([
        'reading_plan',
        'reading_plan_book',
        'rs_session',
        'rs_log',
        'rs_verse_state',
        'rs_day_summary',
      ]),
    );
    expect(
      tableNames.intersection({'rs_daily_log', 'rs_stats', 'rs_book_progress'}),
      isEmpty,
    );

    final indexNames = (await query(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    )).map((row) => row['name']).toSet();
    expect(indexNames, contains('idx_rs_verse_state_plan_book'));
    expect(indexNames, isNot(contains('hash_type_date')));
    expect(indexNames, isNot(contains('hash_rs_book_progress')));

    final planColumns = (await query(
      'PRAGMA table_info(reading_plan)',
    )).map((row) => row['name']).toList();
    expect(planColumns, [
      'id',
      'plan_name',
      'created_at',
      'goal_type',
      'goal_value',
      'is_bookmarked',
    ]);

    final planBookInfo = await query('PRAGMA table_info(reading_plan_book)');
    expect(planBookInfo.map((row) => row['name']).toList(), [
      'reading_plan_id',
      'book_id',
      'ord',
    ]);
    expect(planBookInfo.map((row) => row['pk']).toList(), [1, 2, 0]);

    expect(await query('PRAGMA foreign_key_check'), isEmpty);
  }

  int verseCountFor(int bookId) {
    return createTestVerseInventory(
      bookIds: {bookId},
    ).values.fold<int>(0, (total, verses) => total + verses.length);
  }

  Future<void> createV2Database({
    bool versesReadLast = false,
    required Future<void> Function(Database db) seed,
  }) async {
    final progressColumns = versesReadLast
        ? '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id INT NOT NULL,
    chapter INT NOT NULL,
    verse INT NOT NULL,
    chapters_read INT NOT NULL,
    updated_at DATETIME NOT NULL,
    verses_read INT NOT NULL DEFAULT 0
'''
        : '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id INT NOT NULL,
    chapter INT NOT NULL,
    verse INT NOT NULL,
    chapters_read INT NOT NULL,
    verses_read INT NOT NULL DEFAULT 0,
    updated_at DATETIME NOT NULL
''';

    final db = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
CREATE TABLE rs_daily_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rs_date DATE NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    verses INT NOT NULL
);
''');
          await db.execute('''
CREATE TABLE rs_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rs_daily_log_id INTEGER NOT NULL,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    date_time TIMESTAMP NOT NULL,
    FOREIGN KEY (rs_daily_log_id) REFERENCES rs_daily_log(id)
);
''');
          await db.execute('''
CREATE TABLE rs_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type VARCHAR(1) NOT NULL,
    stats_date DATE NOT NULL,
    rs_seconds INT NOT NULL,
    rs_verses INT NOT NULL,
    goal_reached INT NOT NULL
);
''');
          await db.execute(
            'CREATE UNIQUE INDEX hash_type_date ON rs_stats(type, stats_date);',
          );
          await db.execute('''
CREATE TABLE rs_book_progress (
$progressColumns);
''');
          await db.execute(
            'CREATE UNIQUE INDEX hash_rs_book_progress '
            'ON rs_book_progress(book_id);',
          );
        },
      ),
    );
    await seed(db);
    await db.close();
  }

  test('creates a fresh v9 database with the current schema', () async {
    await openReadingDatabase();

    await expectV9Schema();

    final plans = await database!.readingPlans.list();
    expect(plans, hasLength(1));
    final plan = plans.single;
    expect(
      plan,
      ReadingPlan(
        id: 1,
        planName: 'Whole Bible',
        createdAt: plan.createdAt,
        goalType: GoalType.minutes,
        goalValue: 10,
        isBookmarked: false,
        bookIds: [for (var bookId = 1; bookId <= 66; bookId++) bookId],
      ),
    );

    expect(await database!.session.exportAll(), isEmpty);
    expect(await database!.sessionLog.exportAll(), isEmpty);
    expect(await database!.daySummary.exportAll(), isEmpty);

    final stats = await database!.verseState.getBookStats(1);
    expect(stats.keys.toSet(), {
      for (var bookId = 1; bookId <= 66; bookId++) bookId,
    });
    expect(_snapshotOf(stats[63]!), (
      totalVerses: 13,
      versesRead: 0,
      lastRead: null,
      resumePosition: const Reference(bookId: 63, chapter: 1, verse: 1),
    ));
  });

  test('upgrades a released v2 database through every step to v9', () async {
    const startStr = '2026-05-01T10:00:00.000';
    const endStr = '2026-05-01T10:15:30.000';

    await createV2Database(
      versesReadLast: true,
      seed: (db) async {
        await db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses)
VALUES (1, '2026-05-01', '$startStr', '$endStr', 25);

INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time)
VALUES
  (1, 1, 1, 1, 1, '$startStr'),
  (2, 1, 1, 1, 2, '$startStr'),
  (3, 1, 1, 1, 3, '$startStr'),
  (4, 1, 40, 1, 1, '$startStr');

INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached)
VALUES (1, 'D', '2026-05-01', 930, 25, 1);

INSERT INTO rs_book_progress
    (id, book_id, chapter, verse, chapters_read, verses_read, updated_at)
VALUES
  (1, 1, 1, 4, 0, 3, '2026-05-01T10:15:30.000'),
  (2, 40, 1, 2, 0, 1, '2026-05-02T11:00:00.000');
''');
      },
    );

    await openReadingDatabase(legacyDailyGoal: 'verses-15');

    await expectV9Schema();

    final plan = (await database!.readingPlans.getById(1))!;
    expect(
      plan,
      ReadingPlan(
        id: 1,
        planName: 'Whole Bible',
        createdAt: plan.createdAt,
        goalType: GoalType.verses,
        goalValue: 15,
        isBookmarked: false,
        bookIds: [for (var bookId = 1; bookId <= 66; bookId++) bookId],
      ),
    );

    expect(
      await database!.session.getById(1),
      Session(
        id: 1,
        rsDate: DateTime.parse('2026-05-01'),
        startTime: DateTime.parse(startStr),
        endTime: DateTime.parse(endStr),
        readSeconds: 930,
        verses: 25,
        readingPlanId: 1,
        isManual: false,
      ),
    );

    expect(await database!.sessionLog.listForSession(1), [
      SessionLogEntry(
        id: 1,
        sessionId: 1,
        readingPlanId: 1,
        bookId: 1,
        chapter: 1,
        verse: 1,
        dateTime: DateTime.parse(startStr),
      ),
      SessionLogEntry(
        id: 2,
        sessionId: 1,
        readingPlanId: 1,
        bookId: 1,
        chapter: 1,
        verse: 2,
        dateTime: DateTime.parse(startStr),
      ),
      SessionLogEntry(
        id: 3,
        sessionId: 1,
        readingPlanId: 1,
        bookId: 1,
        chapter: 1,
        verse: 3,
        dateTime: DateTime.parse(startStr),
      ),
      SessionLogEntry(
        id: 4,
        sessionId: 1,
        readingPlanId: 1,
        bookId: 40,
        chapter: 1,
        verse: 1,
        dateTime: DateTime.parse(startStr),
      ),
    ]);

    expect(
      await database!.daySummary.get(1, DateTime(2026, 5, 1)),
      DaySummary(
        readingPlanId: 1,
        rsDate: DateTime(2026, 5, 1),
        rsSeconds: 930,
        rsVerses: 25,
        goalType: GoalType.verses,
        goalValue: 15,
        goalReached: true,
      ),
    );

    expect(await database!.verseState.getReadCount(1, 1, 1, 1), 1);
    expect(await database!.verseState.getReadCount(1, 1, 1, 2), 1);
    expect(await database!.verseState.getReadCount(1, 1, 1, 3), 1);
    expect(await database!.verseState.getReadCount(1, 40, 1, 1), 1);
    expect(await database!.verseState.getReadCount(1, 1, 1, 4), 0);
    expect(await database!.verseState.getReadCount(1, 63, 1, 1), 0);

    final stats = await database!.verseState.getBookStats(1);
    expect(stats.keys, hasLength(66));
    expect(_snapshotOf(stats[1]!), (
      totalVerses: verseCountFor(1),
      versesRead: 3,
      lastRead: DateTime.parse(startStr),
      resumePosition: const Reference(bookId: 1, chapter: 1, verse: 4),
    ));
    expect(_snapshotOf(stats[40]!), (
      totalVerses: verseCountFor(40),
      versesRead: 1,
      lastRead: DateTime.parse(startStr),
      resumePosition: const Reference(bookId: 40, chapter: 1, verse: 2),
    ));
    expect(_snapshotOf(stats[63]!), (
      totalVerses: 13,
      versesRead: 0,
      lastRead: null,
      resumePosition: const Reference(bookId: 63, chapter: 1, verse: 1),
    ));
  });

  test(
    'upgrades v2 sessions with finalization, read times, and summaries',
    () async {
      await createV2Database(
        seed: (db) async {
          await db.execute('''
INSERT INTO rs_daily_log (id, rs_date, start_time, end_time, verses)
VALUES
  (1, '2026-06-01T00:00:00.000', '2026-06-01T10:00:00.000', '2026-06-01T10:10:00.000', 15),
  (2, '2026-06-01T00:00:00.000', '2026-06-01T11:00:00.000', '2026-06-01T11:05:30.000', 10),
  (3, '2026-06-02T00:00:00.000', '2026-06-02T09:00:00.000', '2026-06-02T09:05:00.000', 5),
  (4, '2026-06-02T00:00:00.000', '2026-06-02T09:45:00.000', null, 4),
  (5, '2026-06-03T00:00:00.000', '2026-06-03T08:00:00.000', null, 2),
  (6, '2026-06-04T00:00:00.000', '2026-06-04T07:00:00.000', null, 0);
''');
          await db.execute('''
INSERT INTO rs_log (id, rs_daily_log_id, book_id, chapter, verse, date_time)
VALUES
  (1, 4, 1, 1, 1, '2026-06-02T09:46:00.000'),
  (2, 4, 1, 1, 2, '2026-06-02T09:48:00.000'),
  (3, 4, 1, 1, 3, '2026-06-02T09:49:00.000'),
  (4, 4, 1, 1, 4, '2026-06-02T09:50:00.000'),
  (5, 5, 1, 1, 1, '2026-06-03T08:01:00.000'),
  (6, 5, 1, 1, 2, '2026-06-03T08:02:00.000');
''');
          await db.execute('''
INSERT INTO rs_stats (id, type, stats_date, rs_seconds, rs_verses, goal_reached)
VALUES
  (1, 'D', '2026-06-01T00:00:00.000', 930, 25, 1),
  (2, 'D', '2026-06-02T00:00:00.000', 300, 5, 0),
  (3, 'M', '2026-06-30T00:00:00.000', 9999, 99, 1);
''');
        },
      );

      await openReadingDatabase();

      final plan = (await database!.readingPlans.getById(1))!;
      expect(plan.goalType, GoalType.minutes);
      expect(plan.goalValue, 10);

      final sessions = await database!.session.listForDate(
        DateTime(2026, 6, 1),
        1,
      );
      expect(sessions, hasLength(2));
      expect(sessions[0].id, 1);
      expect(sessions[0].readSeconds, 600);
      expect(sessions[1].id, 2);
      expect(sessions[1].readSeconds, 330);

      expect(
        await database!.session.getById(3),
        Session(
          id: 3,
          rsDate: DateTime(2026, 6, 2),
          startTime: DateTime.parse('2026-06-02T09:00:00.000'),
          endTime: DateTime.parse('2026-06-02T09:05:00.000'),
          readSeconds: 300,
          verses: 5,
          readingPlanId: 1,
          isManual: false,
        ),
      );
      expect(
        await database!.session.getById(4),
        Session(
          id: 4,
          rsDate: DateTime(2026, 6, 2),
          startTime: DateTime.parse('2026-06-02T09:45:00.000'),
          endTime: DateTime.parse('2026-06-02T09:50:00.000'),
          readSeconds: 300,
          verses: 4,
          readingPlanId: 1,
          isManual: false,
        ),
      );
      expect(
        await database!.session.getById(5),
        Session(
          id: 5,
          rsDate: DateTime(2026, 6, 3),
          startTime: DateTime.parse('2026-06-03T08:00:00.000'),
          endTime: DateTime.parse('2026-06-03T08:02:00.000'),
          readSeconds: 120,
          verses: 2,
          readingPlanId: 1,
          isManual: false,
        ),
      );
      expect(
        await database!.session.getById(6),
        Session(
          id: 6,
          rsDate: DateTime(2026, 6, 4),
          startTime: DateTime.parse('2026-06-04T07:00:00.000'),
          verses: 0,
          readingPlanId: 1,
          isManual: false,
        ),
      );

      expect(await database!.sessionLog.listForSession(4), hasLength(4));
      expect(await database!.sessionLog.listForSession(5), hasLength(2));

      expect(
        await database!.daySummary.listBetween(
          1,
          DateTime(2026, 6, 1),
          DateTime(2026, 6, 4),
        ),
        [
          DaySummary(
            readingPlanId: 1,
            rsDate: DateTime(2026, 6, 1),
            rsSeconds: 930,
            rsVerses: 25,
            goalType: GoalType.minutes,
            goalValue: 10,
            goalReached: true,
          ),
          DaySummary(
            readingPlanId: 1,
            rsDate: DateTime(2026, 6, 2),
            rsSeconds: 600,
            rsVerses: 9,
            goalType: GoalType.minutes,
            goalValue: 10,
            goalReached: false,
          ),
          DaySummary(
            readingPlanId: 1,
            rsDate: DateTime(2026, 6, 3),
            rsSeconds: 120,
            rsVerses: 2,
            goalType: GoalType.minutes,
            goalValue: 10,
            goalReached: false,
          ),
          DaySummary(
            readingPlanId: 1,
            rsDate: DateTime(2026, 6, 4),
            rsSeconds: 0,
            rsVerses: 0,
            goalType: GoalType.minutes,
            goalValue: 10,
            goalReached: false,
          ),
        ],
      );
    },
  );
}
