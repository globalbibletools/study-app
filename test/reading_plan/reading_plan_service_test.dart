import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
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
    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);
  });

  Future<List<ReadingPlanDetails>> readSummaries({DateTime? today}) async {
    return database.readModels.getPlanSummaries(today: today);
  }

  Future<ReadingPlanDetails?> planDetails(int planId) async {
    final plans = await readSummaries();
    return plans.where((plan) => plan.readingPlan.id == planId).firstOrNull;
  }

  Future<List<RsBookStats>> readBookStats(int planId) async {
    final progress = await database.readModels.getPlanProgress(planId);
    return progress?.bookStats.values.toList() ?? const [];
  }

  Future<DayProgress> readDayProgress(int planId, DateTime date) async {
    final progress = await database.readModels.getDayProgress(planId, date);
    return progress.toDayProgress();
  }

  Future<List<DayProgress>> readMonthProgress(int planId, DateTime month) {
    return database.readModels.getMonthProgress(planId, month);
  }

  Future<Reference?> readResume(int planId) async {
    final progress = await database.readModels.getPlanProgress(planId);
    return progress?.resumePosition;
  }

  tearDown(() {
    database.dispose();
  });

  test('creates, reads, updates, reorders, and deletes a plan', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Service Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {3, 1, 2},
    );

    final fetchedPlan = await planDetails(savedPlanId);
    expect(fetchedPlan, isNotNull);
    expect(fetchedPlan!.readingPlan.planName, 'Service Test');
    expect(fetchedPlan.readingPlan.goalValue, 15);
    expect(fetchedPlan.books.map((b) => b.bookId), [1, 2, 3]);
    expect(fetchedPlan.resumePosition?.bookId, 1);
    expect(fetchedPlan.resumePosition?.chapter, 1);
    expect(fetchedPlan.resumePosition?.verse, 1);

    await planService.setReadingPlanBookmark(savedPlanId, true);

    final reloadedPlan = await planDetails(savedPlanId);
    expect(reloadedPlan!.readingPlan.isBookmarked, isTrue);

    await database.updateReadingPlanBooks([
      for (var i = 0; i < reloadedPlan.books.length; i++)
        reloadedPlan.books[reloadedPlan.books.length - 1 - i].copyWith(
          readingPlanId: savedPlanId,
          ord: i + 1,
        ),
    ]);

    final reorderedPlan = await planDetails(savedPlanId);
    expect(reorderedPlan!.books.map((b) => b.bookId), [3, 2, 1]);
    expect(reorderedPlan.books.map((b) => b.ord), [1, 2, 3]);

    final allPlans = await readSummaries();
    expect(
      allPlans.where((p) => p.readingPlan.id == savedPlanId),
      hasLength(1),
    );

    await planService.deleteReadingPlan(savedPlanId);
    expect(await planDetails(savedPlanId), isNull);
  });

  test('loads today\'s progress for each listed plan', () async {
    final today = DateTime(2026, 11, 23);
    final versePlanId = await planService.saveReadingPlan(
      planName: 'Verse Goal Plan',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final minutePlanId = await planService.saveReadingPlan(
      planName: 'Minute Goal Plan',
      collectionId: 1,
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {64},
    );
    final untouchedPlanId = await planService.saveReadingPlan(
      planName: 'Untouched Plan',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {65},
    );

    await database.insertSession(
      RsSession(
        rsDate: today,
        startTime: DateTime(2026, 11, 23, 8),
        endTime: DateTime(2026, 11, 23, 8, 10),
        readSeconds: 600,
        verses: 7,
        readingPlanId: versePlanId,
      ),
    );
    await database.upsertDaySummary(versePlanId, today);

    await database.insertSession(
      RsSession(
        rsDate: today,
        startTime: DateTime(2026, 11, 23, 9),
        endTime: DateTime(2026, 11, 23, 9, 5),
        readSeconds: 300,
        verses: 2,
        readingPlanId: minutePlanId,
      ),
    );
    await database.upsertDaySummary(minutePlanId, today);

    final plans = await readSummaries(today: DateTime(2026, 11, 23, 15, 30));

    final verseDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == versePlanId,
    );
    expect(verseDetails.todayProgress?.day, today);
    expect(verseDetails.todayProgress?.verses, 7);
    expect(verseDetails.todayProgress?.goalReached, isTrue);

    final minuteDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == minutePlanId,
    );
    expect(minuteDetails.todayProgress?.minutes, 5);
    expect(minuteDetails.todayProgress?.goalReached, isFalse);

    final untouchedDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == untouchedPlanId,
    );
    expect(untouchedDetails.todayProgress?.empty, isTrue);
    expect(untouchedDetails.todayProgress?.day, today);
  });

  test('loads a single day of progress independently of the month', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Day Progress Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 5, 13, 30);

    await database.insertSession(
      RsSession(
        rsDate: DateTime(date.year, date.month, date.day),
        startTime: date,
        endTime: date.add(const Duration(minutes: 12)),
        readSeconds: 750,
        verses: 7,
        readingPlanId: savedPlanId,
      ),
    );
    await database.upsertDaySummary(savedPlanId, date);

    final progress = await readDayProgress(savedPlanId, date);
    expect(progress.empty, isFalse);
    expect(progress.day, DateTime(2026, 11, 5));
    expect(progress.minutes, 12.5);
    expect(progress.verses, 7);
    expect(progress.goalReached, isTrue);

    final empty = await readDayProgress(savedPlanId, DateTime(2026, 11, 6));
    expect(empty.empty, isTrue);
    expect(empty.day, DateTime(2026, 11, 6));
  });

  test('adds a manual session without touching verse progress', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Session Test',
      collectionId: 1,
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 20);

    final sessionId = await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 12.5,
      verses: 8,
    );

    final session = (await database.getSessionById(sessionId))!;
    expect(session.isManual, isTrue);
    expect(session.rsDate, date);
    expect(session.readSeconds, 750);
    expect(session.verses, 8);
    expect(await database.getRsLogForSession(sessionId), isEmpty);

    final day = await readDayProgress(savedPlanId, date);
    expect(day.empty, isFalse);
    expect(day.minutes, 12.5);
    expect(day.verses, 8);
    expect(day.goalReached, isTrue);

    final month = await readMonthProgress(savedPlanId, date);
    final monthDay = month.singleWhere((entry) => entry.day.day == 20);
    expect(monthDay.minutes, 12.5);
    expect(monthDay.verses, 8);

    final stats = await readBookStats(savedPlanId);
    final ruth = stats.singleWhere((stat) => stat.bookId == 63);
    expect(ruth.versesRead, 0);
    expect(ruth.isComplete, isFalse);

    final counts = await database.getVerseReadCountsForChapter(
      savedPlanId,
      63,
      1,
    );
    expect(counts.values.every((count) => count == 0), isTrue);
    expect(
      await readResume(savedPlanId),
      const Reference(bookId: 63, chapter: 1, verse: 1),
    );
  });

  test('deletes manual sessions and recalculates the day summary', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Delete Test',
      collectionId: 1,
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 20);

    final firstId = await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 6,
      verses: 4,
    );
    final secondId = await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 5,
      verses: 2,
    );

    var day = await readDayProgress(savedPlanId, date);
    expect(day.minutes, 11);
    expect(day.verses, 6);

    expect(await planService.deleteManualSession(firstId), isTrue);

    day = await readDayProgress(savedPlanId, date);
    expect(day.minutes, 5);
    expect(day.verses, 2);

    expect(await planService.deleteManualSession(secondId), isTrue);

    day = await readDayProgress(savedPlanId, date);
    expect(day.empty, isTrue);
    expect(await database.getDaySummary(savedPlanId, date), isNull);
  });

  test('rejects deleting a normal session', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Normal Session Delete Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final now = DateTime.now();
    final normal = await database.insertSession(
      RsSession(
        rsDate: DateTime(now.year, now.month, now.day),
        startTime: now,
        endTime: now,
        readSeconds: 60,
        verses: 1,
        readingPlanId: savedPlanId,
      ),
    );

    await expectLater(
      planService.deleteManualSession(normal.id!),
      throwsA(isA<StateError>()),
    );
    expect(await database.getSessionById(normal.id!), isNotNull);
  });

  test('rejects invalid manual session input', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Validation Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 21);

    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlanId,
        date: date,
        minutes: -1,
        verses: 1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlanId,
        date: date,
        minutes: 1,
        verses: -1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlanId,
        date: date,
        minutes: 0,
        verses: 0,
      ),
      throwsArgumentError,
    );

    expect(await database.getSessionsForDate(date, savedPlanId), isEmpty);
  });
}
