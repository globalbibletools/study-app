import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_backup_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanBackupService backupService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_backup_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    backupService = ReadingPlanBackupService.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
  });

  Future<List<RsSession>> sessionsOn(DateTime date, int planId) async {
    final activity = await database.readModels.getDayActivity(planId, date);
    return [for (final session in activity) session.rsSession];
  }

  Future<Map<int, BookProgress>> bookProgress(int planId) async {
    final summary = (await database.readModels.getPlanSummary(planId))!;
    return summary.bookProgress;
  }

  Future<DayProgress> dayOn(int planId, DateTime date) async {
    final summary = (await database.readModels.getPlanSummary(
      planId,
      today: date,
    ))!;
    expect(summary.today.hasSummary, isTrue);
    return summary.today;
  }

  test('default constructor resolves the database from getIt', () async {
    if (getIt.isRegistered<ReadingSessionDatabase>()) {
      await getIt.unregister<ReadingSessionDatabase>();
    }
    addTearDown(() async {
      if (getIt.isRegistered<ReadingSessionDatabase>()) {
        await getIt.unregister<ReadingSessionDatabase>();
      }
    });
    getIt.registerSingleton<ReadingSessionDatabase>(database);

    final locatorService = ReadingPlanBackupService();

    final bytes = await locatorService.buildBackupBytes();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(payload['format_version'], 2);
  });

  test('builds a versioned backup and restores it from bytes', () async {
    final initialPlanCount =
        (await database.readModels.getPlanSummaries()).length;
    final plan = await database.saveReadingPlan(
      planName: 'Backup Test',
      collectionId: 1,
      goalType: 'verses',
      goalValue: 12,
      orderedBookIds: [1, 2],
    );

    await database.markVerseRead(plan.id!, 1, 1, 1);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dailyLog = await database.insertSession(
      RsSession(
        rsDate: today,
        startTime: now.subtract(const Duration(minutes: 5)),
        endTime: now,
        readSeconds: 300,
        verses: 1,
        readingPlanId: plan.id!,
      ),
    );
    await database.insertLog(
      RsLog(
        sessionId: dailyLog.id!,
        bookId: 1,
        chapter: 1,
        verse: 1,
        dateTime: now,
        readingPlanId: plan.id!,
      ),
    );
    await database.upsertDaySummary(plan.id!, today);

    final bytes = await backupService.buildBackupBytes();
    final payload = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(payload['format_version'], 2);

    final tables = payload['tables'] as Map<String, dynamic>;
    expect(tables['reading_plan'], hasLength(initialPlanCount + 1));
    expect(tables['rs_session'], hasLength(1));
    expect(tables['rs_day_summary'], hasLength(1));
    expect(tables.containsKey('rs_book_progress'), isFalse);
    expect(tables.containsKey('rs_verse_state'), isFalse);
    expect(tables.containsKey('rs_stats'), isFalse);
    expect(tables.containsKey('rs_daily_log'), isFalse);

    await database.deleteReadingPlan(plan.id!);
    expect(
      (await database.readModels.getPlanSummaries()).where(
        (p) => p.planName == 'Backup Test',
      ),
      isEmpty,
    );

    await backupService.restoreBackupBytes(bytes);

    final restoredPlans = (await database.readModels.getPlanSummaries()).where(
      (p) => p.planName == 'Backup Test',
    );
    expect(restoredPlans, hasLength(1));
    expect(restoredPlans.single.dailyGoal.value, 12);
    expect(restoredPlans.single.books.map((b) => b.bookId), [1, 2]);

    final restoredSessions = await sessionsOn(today, plan.id!);
    expect(restoredSessions, hasLength(1));
    expect(restoredSessions.single.verses, 1);

    final restoredSummary = await dayOn(plan.id!, today);
    expect(restoredSummary.verses, 1);
    expect(restoredSummary.seconds, greaterThanOrEqualTo(290));
    expect(restoredSummary.goalValue, 12);

    final chapterCounts = await database.readModels.getVerseReadCounts(
      plan.id!,
      1,
      1,
    );
    expect(chapterCounts[1], 1);
    expect(chapterCounts[2], 0);

    final aggregates = await bookProgress(plan.id!);
    expect(aggregates[1]!.versesRead, 1);
    expect(aggregates[1]!.isComplete, isFalse);
  });

  test('round trips manual sessions without creating verse progress', () async {
    final plan = await database.saveReadingPlan(
      planName: 'Manual Backup Test',
      collectionId: 1,
      goalType: 'verses',
      goalValue: 12,
      orderedBookIds: [63],
    );
    final date = DateTime(2026, 11, 20);
    final manual = await database.insertSession(
      RsSession(
        rsDate: date,
        startTime: DateTime(2026, 11, 20, 8),
        endTime: DateTime(2026, 11, 20, 8, 15),
        readSeconds: 900,
        verses: 7,
        readingPlanId: plan.id!,
        isManual: true,
      ),
    );
    await database.upsertDaySummary(plan.id!, date);

    final payload =
        jsonDecode(utf8.decode(await backupService.buildBackupBytes()))
            as Map<String, dynamic>;
    expect(payload['format_version'], 2);

    final tables = payload['tables'] as Map<String, dynamic>;
    final exportedSessions = (tables['rs_session'] as List).cast<Map>();
    final exportedManual = exportedSessions.singleWhere(
      (row) => row['id'] == manual.id,
    );
    expect(exportedManual['is_manual'], 1);
    expect(
      (tables['rs_log'] as List).where(
        (row) => (row as Map)['rs_session_id'] == manual.id,
      ),
      isEmpty,
    );

    await database.deleteReadingPlan(plan.id!);
    await backupService.restoreBackupJson(jsonEncode(payload));

    final restoredSessions = await sessionsOn(date, plan.id!);
    expect(restoredSessions, hasLength(1));
    expect(restoredSessions.single.isManual, isTrue);
    expect(restoredSessions.single.readSeconds, 900);
    expect(restoredSessions.single.verses, 7);

    final restoredSummary = await dayOn(plan.id!, date);
    expect(restoredSummary.seconds, 900);
    expect(restoredSummary.verses, 7);

    final counts = await database.readModels.getVerseReadCounts(
      plan.id!,
      63,
      1,
    );
    expect(counts.values.every((count) => count == 0), isTrue);
    final stats = await bookProgress(plan.id!);
    expect(stats[63]!.versesRead, 0);

    // Older unreleased v2 backups predate the column; those rows restore as
    // normal sessions.
    for (final row in exportedSessions) {
      row.remove('is_manual');
    }
    await backupService.restoreBackupJson(jsonEncode(payload));

    final defaultedSessions = await sessionsOn(date, plan.id!);
    expect(defaultedSessions.single.isManual, isFalse);
  });

  test(
    'v1 restore rebuilds verse state from rs_log and materializes zeros',
    () async {
      await database.restoreBackupTables({
        'rs_daily_log': [
          {
            'id': 1,
            'rs_date': '2026-04-30',
            'start_time': '2026-04-30T09:00:00.000',
            'end_time': '2026-04-30T09:20:00.000',
            'verses': 3,
          },
        ],
        'rs_log': [
          {
            'id': 1,
            'rs_daily_log_id': 1,
            'book_id': 1,
            'chapter': 1,
            'verse': 1,
            'date_time': '2026-04-30T09:05:00.000',
          },
          {
            'id': 2,
            'rs_daily_log_id': 1,
            'book_id': 1,
            'chapter': 1,
            'verse': 1,
            'date_time': '2026-04-30T09:10:00.000',
          },
          {
            'id': 3,
            'rs_daily_log_id': 1,
            'book_id': 1,
            'chapter': 1,
            'verse': 2,
            'date_time': '2026-04-30T09:15:00.000',
          },
        ],
        'rs_stats': [
          {
            'id': 1,
            'type': 'D',
            'stats_date': '2026-04-30',
            'rs_seconds': 1200,
            'rs_verses': 3,
            'goal_reached': 1,
          },
        ],
        'rs_book_progress': [
          {
            'id': 1,
            'book_id': 1,
            'chapter': 1,
            'verse': 15,
            'chapters_read': 0,
            'verses_read': 99,
            'updated_at': '2026-04-30T09:20:00.000',
          },
        ],
      }, formatVersion: 1);

      final plan = await database.getReadingPlanById(1);
      expect(plan, isNotNull);
      expect(plan!.books, hasLength(66));

      // The v1 session rows land in rs_session with the plan remapped to 1.
      final restoredSessions = await sessionsOn(DateTime(2026, 4, 30), 1);
      expect(restoredSessions, hasLength(1));
      expect(restoredSessions.single.verses, 3);
      expect(
        restoredSessions.single.endTime,
        DateTime.parse('2026-04-30T09:20:00.000'),
      );

      // The day summary is rebuilt: totals recomputed from the imported
      // session, flag preserved from the payload's daily rs_stats row.
      final summary = await dayOn(1, DateTime(2026, 4, 30));
      expect(summary.seconds, 1200);
      expect(summary.verses, 3);
      expect(summary.goalReached, isTrue);

      final chapterCounts = await database.readModels.getVerseReadCounts(
        1,
        1,
        1,
      );
      expect(chapterCounts, hasLength(31));
      expect(chapterCounts[1], 2);
      expect(chapterCounts[2], 1);
      expect(chapterCounts[31], 0);

      final aggregates = await bookProgress(1);
      expect(aggregates[1]!.versesRead, 2);
    },
  );

  test('rejects old-shape v2 backups that carry rs_daily_log', () async {
    // Format v2 is unreleased; dev devices may hold old-shape v2 files saved
    // before the format was finalized. They must fail loudly, not silently
    // restore partial data.
    await expectLater(
      database.restoreBackupTables({
        'reading_plan': [],
        'reading_plan_book': [],
        'rs_daily_log': [],
        'rs_log': [],
        'rs_stats': [],
      }, formatVersion: 2),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('rs_daily_log'),
        ),
      ),
    );
  });

  test('rejects v2 backups that are missing rs_day_summary', () async {
    await expectLater(
      database.restoreBackupTables({
        'reading_plan': [],
        'reading_plan_book': [],
        'rs_session': [],
        'rs_log': [],
      }, formatVersion: 2),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('rs_day_summary'),
        ),
      ),
    );
  });
}
