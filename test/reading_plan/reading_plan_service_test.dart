import 'package:flutter_test/flutter_test.dart';
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
    planService = ReadingPlanService.withDependencies(
      database: database,
      bibleNavigation: createTestBibleNavigation(),
    );
  });

  tearDown(() {
    database.dispose();
  });

  test('creates, reads, updates, reorders, and deletes a plan', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Service Test',
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {3, 1, 2},
    );

    final fetchedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(fetchedPlan, isNotNull);
    expect(fetchedPlan!.readingPlan.planName, 'Service Test');
    expect(fetchedPlan.readingPlan.goalValue, 15);
    expect(fetchedPlan.books.map((b) => b.bookId), [1, 2, 3]);
    expect(fetchedPlan.resumePosition?.bookId, 1);
    expect(fetchedPlan.resumePosition?.chapter, 1);
    expect(fetchedPlan.resumePosition?.verse, 1);

    final bookmarkedPlan = await planService.setReadingPlanBookmark(
      fetchedPlan.readingPlan,
      true,
    );
    expect(bookmarkedPlan.isBookmarked, isTrue);

    final reloadedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(reloadedPlan!.readingPlan.isBookmarked, isTrue);

    await planService.reorderReadingPlanBooks(
      savedPlan.id!,
      reloadedPlan.books.reversed.toList(),
    );

    final reorderedPlan = await planService.getReadingPlanById(savedPlan.id!);
    expect(reorderedPlan!.books.map((b) => b.bookId), [3, 2, 1]);
    expect(reorderedPlan.books.map((b) => b.ord), [1, 2, 3]);

    final allPlans = await planService.getReadingPlans();
    expect(
      allPlans.where((p) => p.readingPlan.id == savedPlan.id),
      hasLength(1),
    );

    await planService.deleteReadingPlan(savedPlan.id!);
    expect(await planService.getReadingPlanById(savedPlan.id!), isNull);
  });

  test('loads today\'s progress for each listed plan', () async {
    final today = DateTime(2026, 11, 23);
    final versePlan = await planService.saveReadingPlan(
      planName: 'Verse Goal Plan',
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final minutePlan = await planService.saveReadingPlan(
      planName: 'Minute Goal Plan',
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {64},
    );
    final untouchedPlan = await planService.saveReadingPlan(
      planName: 'Untouched Plan',
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
        readingPlanId: versePlan.id!,
      ),
    );
    await database.upsertDaySummary(versePlan.id!, today);

    await database.insertSession(
      RsSession(
        rsDate: today,
        startTime: DateTime(2026, 11, 23, 9),
        endTime: DateTime(2026, 11, 23, 9, 5),
        readSeconds: 300,
        verses: 2,
        readingPlanId: minutePlan.id!,
      ),
    );
    await database.upsertDaySummary(minutePlan.id!, today);

    final plans = await planService.getReadingPlansWithProgress(
      today: DateTime(2026, 11, 23, 15, 30),
    );

    final verseDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == versePlan.id,
    );
    expect(verseDetails.todayProgress?.day, today);
    expect(verseDetails.todayProgress?.verses, 7);
    expect(verseDetails.todayProgress?.goalReached, isTrue);

    final minuteDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == minutePlan.id,
    );
    expect(minuteDetails.todayProgress?.minutes, 5);
    expect(minuteDetails.todayProgress?.goalReached, isFalse);

    final untouchedDetails = plans.singleWhere(
      (plan) => plan.readingPlan.id == untouchedPlan.id,
    );
    expect(untouchedDetails.todayProgress?.empty, isTrue);
    expect(untouchedDetails.todayProgress?.day, today);
  });

  test('loads a single day of progress independently of the month', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Day Progress Test',
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
        readingPlanId: savedPlan.id!,
      ),
    );
    await database.upsertDaySummary(savedPlan.id!, date);

    final progress = await planService.getDayProgress(savedPlan.id!, date);
    expect(progress.empty, isFalse);
    expect(progress.day, DateTime(2026, 11, 5));
    expect(progress.minutes, 12.5);
    expect(progress.verses, 7);
    expect(progress.goalReached, isTrue);

    final empty = await planService.getDayProgress(
      savedPlan.id!,
      DateTime(2026, 11, 6),
    );
    expect(empty.empty, isTrue);
    expect(empty.day, DateTime(2026, 11, 6));
  });

  test('adds a manual session without touching verse progress', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Manual Session Test',
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 20);

    final details = await planService.addManualSession(
      readingPlanId: savedPlan.id!,
      date: date,
      minutes: 12.5,
      verses: 8,
    );

    expect(details.rsSession.isManual, isTrue);
    expect(details.rsSession.rsDate, date);
    expect(details.rsSession.readSeconds, 750);
    expect(details.rsSession.verses, 8);
    expect(await database.getRsLogForSession(details.rsSession.id!), isEmpty);

    final day = await planService.getDayProgress(savedPlan.id!, date);
    expect(day.empty, isFalse);
    expect(day.minutes, 12.5);
    expect(day.verses, 8);
    expect(day.goalReached, isTrue);

    final month = await planService.getMonthProgress(savedPlan.id!, date);
    final monthDay = month.singleWhere((entry) => entry.day.day == 20);
    expect(monthDay.minutes, 12.5);
    expect(monthDay.verses, 8);

    final stats = await planService.getBooksStats(savedPlan.id!);
    final ruth = stats.singleWhere((stat) => stat.bookId == 63);
    expect(ruth.versesRead, 0);
    expect(ruth.isComplete, isFalse);

    final counts = await database.getVerseReadCountsForChapter(
      savedPlan.id!,
      63,
      1,
    );
    expect(counts.values.every((count) => count == 0), isTrue);
    expect(
      await planService.getResumeReference(savedPlan.id!),
      const Reference(bookId: 63, chapter: 1, verse: 1),
    );
  });

  test('deletes manual sessions and recalculates the day summary', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Manual Delete Test',
      goalType: GoalType.minutes,
      goalValue: 10,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 20);

    final first = await planService.addManualSession(
      readingPlanId: savedPlan.id!,
      date: date,
      minutes: 6,
      verses: 4,
    );
    final second = await planService.addManualSession(
      readingPlanId: savedPlan.id!,
      date: date,
      minutes: 5,
      verses: 2,
    );

    var day = await planService.getDayProgress(savedPlan.id!, date);
    expect(day.minutes, 11);
    expect(day.verses, 6);

    expect(await planService.deleteManualSession(first.rsSession.id!), isTrue);

    day = await planService.getDayProgress(savedPlan.id!, date);
    expect(day.minutes, 5);
    expect(day.verses, 2);

    expect(await planService.deleteManualSession(second.rsSession.id!), isTrue);

    day = await planService.getDayProgress(savedPlan.id!, date);
    expect(day.empty, isTrue);
    expect(await database.getDaySummary(savedPlan.id!, date), isNull);
  });

  test('rejects deleting a normal session', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Normal Session Delete Test',
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
        readingPlanId: savedPlan.id!,
      ),
    );

    await expectLater(
      planService.deleteManualSession(normal.id!),
      throwsA(isA<StateError>()),
    );
    expect(await database.getSessionById(normal.id!), isNotNull);
  });

  test('rejects invalid manual session input', () async {
    final savedPlan = await planService.saveReadingPlan(
      planName: 'Manual Validation Test',
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );
    final date = DateTime(2026, 11, 21);

    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlan.id!,
        date: date,
        minutes: -1,
        verses: 1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlan.id!,
        date: date,
        minutes: 1,
        verses: -1,
      ),
      throwsArgumentError,
    );
    await expectLater(
      planService.addManualSession(
        readingPlanId: savedPlan.id!,
        date: date,
        minutes: 0,
        verses: 0,
      ),
      throwsArgumentError,
    );

    expect(await database.getSessionsForDate(date, savedPlan.id!), isEmpty);
  });
}
