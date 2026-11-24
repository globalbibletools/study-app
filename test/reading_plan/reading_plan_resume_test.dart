import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_resume_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);
  });

  tearDown(() {
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  Future<void> addLog(
    int planId,
    int bookId,
    int chapter,
    int verse,
    DateTime dateTime,
  ) async {
    final dailyLog = await database.session.commit(
      Session(
        rsDate: DateTime(dateTime.year, dateTime.month, dateTime.day),
        startTime: dateTime,
        verses: 1,
        readingPlanId: planId,
      ),
    );
    await database.sessionLog.append(
      SessionLogEntry(
        sessionId: dailyLog.id!,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: dateTime,
        readingPlanId: planId,
      ),
    );
  }

  Future<Reference?> resumeFor(int planId) async {
    return (await database.queries.getPlanSummary(planId))?.resumePosition;
  }

  test('starts at the first verse when the plan has no reads', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 63);
    expect(resume.chapter, 1);
    expect(resume.verse, 1);
  });

  test('returns the verse after the last read verse', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await addLog(planId, 63, 1, 5, DateTime(2026, 5, 1, 10));

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 63);
    expect(resume.chapter, 1);
    expect(resume.verse, 6);
  });

  test(
    'plan resume advances to the next verse even when that verse is read',
    () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Resume Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63, 64],
      );
      await database.verseState.markRead(planId, 63, 1, 6);
      await addLog(planId, 63, 1, 5, DateTime(2026, 5, 1, 10));

      final resume = await resumeFor(planId);

      expect(resume, isNotNull);
      expect(resume!.bookId, 63);
      expect(resume.chapter, 1);
      expect(resume.verse, 6);
    },
  );

  test('plan resume moves to the next book in plan order', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await addLog(planId, 63, 1, 13, DateTime(2026, 5, 1, 10));

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 64);
    expect(resume.chapter, 1);
    expect(resume.verse, 1);
  });

  test('plan resume is null after the final verse in the plan', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await addLog(planId, 64, 1, 15, DateTime(2026, 5, 1, 10));

    expect(await resumeFor(planId), isNull);
  });

  test('uses the latest log entry in the plan', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await addLog(planId, 63, 1, 5, DateTime(2026, 5, 1, 10));
    await addLog(planId, 64, 1, 2, DateTime(2026, 5, 2, 10));

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 64);
    expect(resume.chapter, 1);
    expect(resume.verse, 3);
  });

  test('moves to the next chapter after the last verse', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [19],
    );
    await addLog(planId, 19, 1, 6, DateTime(2026, 5, 1, 10));

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 19);
    expect(resume.chapter, 2);
    expect(resume.verse, 1);
  });

  test('follows plan order after the last verse of the final book', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await addLog(planId, 64, 1, 15, DateTime(2026, 5, 1, 10));

    expect(await resumeFor(planId), isNull);

    final plan = (await database.readingPlans.getById(planId))!;
    await planService.reorderReadingPlanBooks(
      planId,
      plan.bookIds.reversed.toList(),
    );

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 63);
    expect(resume.chapter, 1);
    expect(resume.verse, 1);
  });

  test('list read model uses the log-derived resume position', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63, 64],
    );
    await database.verseState.markRead(planId, 63, 1, 5);
    await addLog(planId, 63, 1, 5, DateTime(2026, 5, 1, 10));

    final plans = await database.queries.getPlanSummaries();
    final summary = plans.firstWhere((plan) => plan.planId == planId);

    expect(summary.totalVerses, 28);
    expect(summary.versesRead, 1);
    expect(summary.resumePosition, isNotNull);
    expect(summary.resumePosition!.bookId, 63);
    expect(summary.resumePosition!.chapter, 1);
    expect(summary.resumePosition!.verse, 6);
  });

  test('skips verse numbers missing from the chapter inventory', () async {
    database.dispose();
    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_resume_gap_test.db',
      verseInventoryProvider: (bookIds) async {
        final inventory = createTestVerseInventory(bookIds: bookIds);
        if (bookIds.contains(40)) {
          inventory[(40, 16)] = [
            1,
            2,
            for (int verse = 4; verse <= 28; verse++) verse,
          ];
        }
        return inventory;
      },
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);

    final planId = await planService.saveReadingPlan(
      planName: 'Resume Gap Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [40],
    );
    await addLog(planId, 40, 16, 2, DateTime(2026, 5, 1, 10));

    final resume = await resumeFor(planId);

    expect(resume, isNotNull);
    expect(resume!.bookId, 40);
    expect(resume.chapter, 16);
    expect(resume.verse, 4);
  });
}
