import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
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

  tearDown(() {
    database.dispose();
  });

  test('creates, reads, updates, reorders, and deletes a plan', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Service Test',
      goalType: GoalType.verses,
      goalValue: 15,
      bookIds: [1, 2, 3],
    );

    final fetchedPlan = (await database.readingPlans.getById(savedPlanId))!;
    expect(fetchedPlan.planName, 'Service Test');
    expect(fetchedPlan.goalValue, 15);
    expect(fetchedPlan.bookIds, [1, 2, 3]);
    final summary = (await database.queries.getPlanSummary(savedPlanId))!;
    expect(
      summary.resumeTarget,
      const Reference(bookId: 1, chapter: 1, verse: 1),
    );

    await planService.setReadingPlanBookmark(savedPlanId, true);

    final reloadedPlan = (await database.readingPlans.getById(savedPlanId))!;
    expect(reloadedPlan.isBookmarked, isTrue);

    await planService.reorderReadingPlanBooks(
      savedPlanId,
      reloadedPlan.bookIds.reversed.toList(),
    );

    final reorderedPlan = (await database.readingPlans.getById(savedPlanId))!;
    expect(reorderedPlan.bookIds, [3, 2, 1]);

    final allPlans = await database.queries.getPlanSummaries();
    expect(allPlans.where((plan) => plan.planId == savedPlanId), hasLength(1));

    await planService.deleteReadingPlan(savedPlanId);
    expect(await database.readingPlans.getById(savedPlanId), isNull);
  });

  test('loads today\'s progress for each listed plan', () async {
    final today = DateTime(2026, 11, 23);
    final versePlanId = await planService.saveReadingPlan(
      planName: 'Verse Goal Plan',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [63],
    );
    final minutePlanId = await planService.saveReadingPlan(
      planName: 'Minute Goal Plan',
      goalType: GoalType.minutes,
      goalValue: 10,
      bookIds: [64],
    );
    final untouchedPlanId = await planService.saveReadingPlan(
      planName: 'Untouched Plan',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [65],
    );

    await database.session.commit(
      Session(
        rsDate: today,
        startTime: DateTime(2026, 11, 23, 8),
        endTime: DateTime(2026, 11, 23, 8, 10),
        readSeconds: 600,
        verses: 7,
        readingPlanId: versePlanId,
      ),
    );
    await database.daySummary.upsert(versePlanId, today);

    await database.session.commit(
      Session(
        rsDate: today,
        startTime: DateTime(2026, 11, 23, 9),
        endTime: DateTime(2026, 11, 23, 9, 5),
        readSeconds: 300,
        verses: 2,
        readingPlanId: minutePlanId,
      ),
    );
    await database.daySummary.upsert(minutePlanId, today);

    final plans = await database.queries.getPlanSummaries(
      today: DateTime(2026, 11, 23, 15, 30),
    );

    final verseDetails = plans.singleWhere(
      (plan) => plan.planId == versePlanId,
    );
    expect(verseDetails.today.day, today);
    expect(verseDetails.today.verses, 7);
    expect(verseDetails.today.goalReached, isTrue);

    final minuteDetails = plans.singleWhere(
      (plan) => plan.planId == minutePlanId,
    );
    expect(minuteDetails.today.minutes, 5);
    expect(minuteDetails.today.goalReached, isFalse);

    final untouchedDetails = plans.singleWhere(
      (plan) => plan.planId == untouchedPlanId,
    );
    expect(untouchedDetails.today.hasSummary, isFalse);
    expect(untouchedDetails.today.day, today);
  });

  test('loads a single day of progress independently of the month', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Day Progress Test',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [63],
    );
    final date = DateTime(2026, 11, 5, 13, 30);

    await database.session.commit(
      Session(
        rsDate: DateTime(date.year, date.month, date.day),
        startTime: date,
        endTime: date.add(const Duration(minutes: 12)),
        readSeconds: 750,
        verses: 7,
        readingPlanId: savedPlanId,
      ),
    );
    await database.daySummary.upsert(savedPlanId, date);

    final progress = await database.queries.getDayProgress(savedPlanId, date);
    expect(progress.hasSummary, isTrue);
    expect(progress.day, DateTime(2026, 11, 5));
    expect(progress.minutes, 12.5);
    expect(progress.verses, 7);
    expect(progress.goalReached, isTrue);

    final empty = await database.queries.getDayProgress(
      savedPlanId,
      DateTime(2026, 11, 6),
    );
    expect(empty.hasSummary, isFalse);
    expect(empty.day, DateTime(2026, 11, 6));
  });

  test('adds a manual session without touching verse progress', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Session Test',
      goalType: GoalType.minutes,
      goalValue: 10,
      bookIds: [63],
    );
    final date = DateTime(2026, 11, 20);

    await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 12.5,
      verses: 8,
    );

    final details = (await database.queries.getDayActivity(
      savedPlanId,
      date,
    )).sessions.single;

    expect(details.isManual, isTrue);
    expect(details.readSeconds, 750);
    expect(details.verses, 8);
    expect(details.ranges, isEmpty);
    expect(await database.getRsLogForSession(details.sessionId), isEmpty);

    final day = await database.queries.getDayProgress(savedPlanId, date);
    expect(day.hasSummary, isTrue);
    expect(day.minutes, 12.5);
    expect(day.verses, 8);
    expect(day.goalReached, isTrue);

    final monthDay = (await database.queries.getMonthDayProgress(
      savedPlanId,
      date,
    ))[20]!;
    expect(monthDay.minutes, 12.5);
    expect(monthDay.verses, 8);

    final planSummary = (await database.queries.getPlanSummary(savedPlanId))!;
    final ruth = planSummary.bookProgress[63]!;
    expect(ruth.versesRead, 0);
    expect(ruth.isComplete, isFalse);

    final counts = await database.getVerseReadCountsForChapter(
      savedPlanId,
      63,
      1,
    );
    expect(counts.values.every((count) => count == 0), isTrue);
    expect(
      (await database.queries.getPlanSummary(savedPlanId))!.resumePosition,
      const Reference(bookId: 63, chapter: 1, verse: 1),
    );
  });

  test('deletes manual sessions and recalculates the day summary', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Delete Test',
      goalType: GoalType.minutes,
      goalValue: 10,
      bookIds: [63],
    );
    final date = DateTime(2026, 11, 20);

    await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 6,
      verses: 4,
    );
    final first = (await database.queries.getDayActivity(
      savedPlanId,
      date,
    )).sessions.single;
    await planService.addManualSession(
      readingPlanId: savedPlanId,
      date: date,
      minutes: 5,
      verses: 2,
    );
    final second = (await database.queries.getDayActivity(
      savedPlanId,
      date,
    )).sessions.singleWhere((session) => session.sessionId != first.sessionId);

    var day = await database.queries.getDayProgress(savedPlanId, date);
    expect(day.minutes, 11);
    expect(day.verses, 6);

    await planService.deleteManualSession(first.sessionId);

    day = await database.queries.getDayProgress(savedPlanId, date);
    expect(day.minutes, 5);
    expect(day.verses, 2);

    await planService.deleteManualSession(second.sessionId);

    day = await database.queries.getDayProgress(savedPlanId, date);
    expect(day.hasSummary, isFalse);
    expect(await database.getDaySummary(savedPlanId, date), isNull);
  });

  test('rejects deleting a normal session', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Normal Session Delete Test',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [63],
    );
    final now = DateTime.now();
    final normal = await database.session.commit(
      Session(
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
    expect(await database.session.getById(normal.id!), isNotNull);
  });

  test('rejects invalid manual session input', () async {
    final savedPlanId = await planService.saveReadingPlan(
      planName: 'Manual Validation Test',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [63],
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
