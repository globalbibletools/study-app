import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_read_models_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    for (final summary in await database.readModels.getPlanSummaries()) {
      await database.deleteReadingPlan(summary.planId);
    }
  });

  tearDown(() {
    database.dispose();
  });

  Future<ReadingPlan> createPlan(
    String name, {
    List<int> books = const [63],
    String goalType = 'V',
    int goalValue = 10,
    bool bookmark = false,
  }) async {
    final plan = await database.saveReadingPlan(
      planName: name,
      collectionId: 1,
      goalType: goalType,
      goalValue: goalValue,
      orderedBookIds: books,
    );
    if (bookmark) {
      await database.updateReadingPlan(plan.copyWith(isBookmarked: true));
    }
    return plan;
  }

  Future<RsSession> addSession(
    int planId,
    DateTime dateTime, {
    int readSeconds = 0,
    int verses = 0,
    bool isManual = false,
  }) {
    return database.insertSession(
      RsSession(
        rsDate: DateTime(dateTime.year, dateTime.month, dateTime.day),
        startTime: dateTime,
        endTime: dateTime.add(Duration(seconds: readSeconds)),
        readSeconds: readSeconds,
        verses: verses,
        readingPlanId: planId,
        isManual: isManual,
      ),
    );
  }

  Future<void> addLog(
    RsSession session,
    int bookId,
    int chapter,
    int verse,
    DateTime dateTime,
  ) async {
    await database.insertLog(
      RsLog(
        sessionId: session.id!,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: dateTime,
        readingPlanId: session.readingPlanId,
      ),
    );
    await database.markVerseRead(
      session.readingPlanId,
      bookId,
      chapter,
      verse,
      timestamp: dateTime,
    );
  }

  group('plan configs', () {
    test('reads identity, ordered books, goals, and bookmarks', () async {
      final first = await createPlan(
        'First',
        books: [64, 63],
        goalType: 'M',
        goalValue: 20,
        bookmark: true,
      );
      final second = await createPlan('Second', books: [8]);
      await database.markVerseRead(first.id!, 63, 1, 1);

      final summaries = await database.readModels.getPlanSummaries();
      expect(summaries.map((summary) => summary.planId), [first.id, second.id]);
      expect(summaries.first.isBookmarked, isTrue);

      final config = (await database.readModels.getPlanConfig(first.id!))!;
      expect(config.planName, 'First');
      expect(config.collectionId, 1);
      expect(config.dailyGoal.type, GoalType.minutes);
      expect(config.dailyGoal.value, 20);
      expect(config.books.map((book) => book.bookId), [64, 63]);
      expect(config.bookIds, [64, 63]);

      final firstSummary = summaries.first;
      expect(firstSummary.totalVerses, 28);
      expect(firstSummary.versesRead, 1);
      expect(firstSummary.progress.bookProgress[63]!.versesRead, 1);

      final secondSummary = summaries.last;
      expect(secondSummary.totalVerses, 85);
    });

    test('returns null or an empty list for missing plans', () async {
      expect(await database.readModels.getPlanConfig(999), isNull);
      expect(await database.readModels.getPlanSummary(999), isNull);
      expect(await database.readModels.getPlanSummaries(), isEmpty);
    });
  });

  group('plan progress', () {
    test(
      'derives totals from materialized verse state and isolates plans',
      () async {
        final first = await createPlan('First', books: [63, 64]);
        final second = await createPlan('Second', books: [8]);

        await database.markVerseRead(first.id!, 63, 1, 1);
        await database.markVerseRead(first.id!, 63, 1, 2);
        await database.markVerseRead(first.id!, 64, 1, 1);

        final progress = (await database.readModels.getPlanSummary(
          first.id!,
        ))!.progress;
        expect(progress.totalVerses, 28);
        expect(progress.versesRead, 3);
        expect(progress.booksRead, 0);
        expect(progress.bookProgress.keys, [63, 64]);
        expect(progress.bookProgress[63]!.versesRead, 2);
        expect(progress.bookProgress[64]!.versesRead, 1);

        final other = (await database.readModels.getPlanSummary(
          second.id!,
        ))!.progress;
        expect(other.totalVerses, 85);
        expect(other.versesRead, 0);
        expect(other.bookProgress.keys, [8]);
      },
    );

    test('reports book completion and whole-plan completion', () async {
      final single = await createPlan('Single', books: [63]);
      for (int verse = 1; verse <= 13; verse++) {
        await database.markVerseRead(single.id!, 63, 1, verse);
      }

      var progress = (await database.readModels.getPlanSummary(
        single.id!,
      ))!.progress;
      expect(progress.booksRead, 1);
      expect(progress.isComplete, isTrue);
      expect(progress.bookProgress[63]!.isComplete, isTrue);

      final multi = await createPlan('Multi', books: [63, 64]);
      for (int verse = 1; verse <= 13; verse++) {
        await database.markVerseRead(multi.id!, 63, 1, verse);
      }
      progress = (await database.readModels.getPlanSummary(
        multi.id!,
      ))!.progress;
      expect(progress.booksRead, 1);
      expect(progress.isComplete, isFalse);
    });

    test('resume positions follow the latest log in plan order', () async {
      final plan = await createPlan('Resume', books: [63, 64]);
      final firstSession = await addSession(plan.id!, DateTime(2026, 5, 1, 9));
      await addLog(firstSession, 63, 1, 5, DateTime(2026, 5, 1, 9));
      final secondSession = await addSession(plan.id!, DateTime(2026, 5, 2, 9));
      await addLog(secondSession, 64, 1, 2, DateTime(2026, 5, 2, 9));

      final progress = (await database.readModels.getPlanSummary(
        plan.id!,
      ))!.progress;
      expect(
        progress.resumePosition,
        const Reference(bookId: 64, chapter: 1, verse: 3),
      );

      await addLog(secondSession, 64, 1, 15, DateTime(2026, 5, 2, 10));
      expect(
        (await database.readModels.getPlanSummary(
          plan.id!,
        ))!.progress.resumePosition,
        isNull,
      );
    });

    test(
      'excludes verse numbers missing from the materialized inventory',
      () async {
        database.dispose();
        database = ReadingSessionDatabase.withDependencies(
          databaseName: 'reading_plan_read_models_gap_test.db',
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

        final plan = await createPlan('Gap', books: [40]);
        final summary = (await database.readModels.getPlanSummary(plan.id!))!;

        expect(summary.totalVerses, 1067);
        expect(summary.progress.bookProgress[40]!.totalVerses, 1067);

        final states = await database.readModels.getVerseReadCounts(
          plan.id!,
          40,
          16,
        );
        expect(states.containsKey(3), isFalse);
        expect(states[4], 0);
      },
    );
  });

  group('day progress', () {
    test('distinguishes a missing summary from zero activity', () async {
      final plan = await createPlan('Day', goalValue: 5);
      final day = DateTime(2026, 11, 5);

      var progress = (await database.readModels.getPlanSummary(
        plan.id!,
        today: day,
      ))!.today;
      expect(progress.hasSummary, isFalse);
      expect(progress.empty, isTrue);

      await database.upsertDaySummary(plan.id!, day);
      progress = (await database.readModels.getPlanSummary(
        plan.id!,
        today: day,
      ))!.today;
      expect(progress.hasSummary, isTrue);
      expect(progress.seconds, 0);
      expect(progress.verses, 0);
      expect(progress.goalReached, isFalse);
      expect(progress.empty, isFalse);
    });

    test('reads stored totals, goalReached, and the goal snapshot', () async {
      final plan = await createPlan('Day', goalValue: 5);
      final day = DateTime(2026, 11, 5);
      await addSession(
        plan.id!,
        DateTime(2026, 11, 5, 9),
        readSeconds: 750,
        verses: 7,
      );
      await database.upsertDaySummary(plan.id!, day);

      final progress = (await database.readModels.getPlanSummary(
        plan.id!,
        today: day,
      ))!.today;
      expect(progress.hasSummary, isTrue);
      expect(progress.seconds, 750);
      expect(progress.verses, 7);
      expect(progress.goalReached, isTrue);
      expect(progress.goalType, 'V');
      expect(progress.goalValue, 5);
      expect(progress.minutes, 12.5);

      await database.updateReadingPlan(plan.copyWith(goalValue: 20));
      final afterGoalChange = (await database.readModels.getPlanSummary(
        plan.id!,
        today: day,
      ))!.today;
      expect(afterGoalChange.goalValue, 5);
      expect(afterGoalChange.goalReached, isTrue);

      final empty = (await database.readModels.getPlanSummary(
        plan.id!,
        today: DateTime(2026, 11, 6),
      ))!.today;
      expect(empty.hasSummary, isFalse);
      expect(empty.day, DateTime(2026, 11, 6));
    });
  });

  group('month progress', () {
    test('fills every day and maps summaries to the right day', () async {
      final plan = await createPlan('Month', goalValue: 5);
      await addSession(
        plan.id!,
        DateTime(2026, 11, 5, 9),
        readSeconds: 750,
        verses: 7,
      );
      await database.upsertDaySummary(plan.id!, DateTime(2026, 11, 5));
      await database.upsertDaySummary(plan.id!, DateTime(2026, 11, 20));
      await addSession(plan.id!, DateTime(2026, 12, 1, 9), verses: 2);
      await database.upsertDaySummary(plan.id!, DateTime(2026, 12, 1));

      final month = await database.readModels.getMonthProgress(
        plan.id!,
        DateTime(2026, 11, 1),
      );
      expect(month, hasLength(30));
      for (int index = 0; index < month.length; index++) {
        expect(month[index].day, DateTime(2026, 11, index + 1));
      }
      expect(month[4].empty, isFalse);
      expect(month[4].verses, 7);
      expect(month[4].minutes, 12.5);
      expect(month[4].goalReached, isTrue);
      expect(month[19].empty, isFalse);
      expect(month[19].verses, 0);
      expect(month[1].empty, isTrue);
      expect(month.every((entry) => entry.day.month == 11), isTrue);
    });

    test('returns an empty month when no summaries exist', () async {
      final plan = await createPlan('Month');
      final month = await database.readModels.getMonthProgress(
        plan.id!,
        DateTime(2026, 2, 1),
      );
      expect(month, hasLength(28));
      expect(month.every((entry) => entry.empty), isTrue);
    });
  });

  group('day activity', () {
    test(
      'returns only the plan and day, folds ranges, and totals sessions',
      () async {
        final plan = await createPlan('Activity', books: [63, 64]);
        final otherPlan = await createPlan('Other', books: [8]);
        final day = DateTime(2026, 11, 17);

        final first = await addSession(plan.id!, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 1, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 2, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 3, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 5, DateTime(2026, 11, 17, 9));
        await addLog(first, 64, 1, 1, DateTime(2026, 11, 17, 9));

        final second = await addSession(
          plan.id!,
          DateTime(2026, 11, 17, 14),
          readSeconds: 300,
          verses: 2,
        );
        await addLog(second, 63, 2, 1, DateTime(2026, 11, 17, 14));
        await addLog(second, 63, 2, 2, DateTime(2026, 11, 17, 14));

        final otherSession = await addSession(
          otherPlan.id!,
          DateTime(2026, 11, 17, 10),
        );
        await addLog(otherSession, 8, 1, 1, DateTime(2026, 11, 17, 10));

        final otherDaySession = await addSession(
          plan.id!,
          DateTime(2026, 11, 18, 9),
        );
        await addLog(otherDaySession, 63, 1, 1, DateTime(2026, 11, 18, 9));

        final activity = await database.readModels.getDayActivity(
          plan.id!,
          day,
        );
        expect(activity, hasLength(2));
        expect(activity.first.rsSession.id, first.id);
        expect(activity.last.rsSession.id, second.id);
        expect(
          activity.first.progress.map(
            (range) =>
                (range.bookId, range.chapter, range.fromVerse, range.toVerse),
          ),
          [(63, 1, 1, 3), (63, 1, 5, 5), (64, 1, 1, 1)],
        );
        expect(
          activity.last.progress.map(
            (range) =>
                (range.bookId, range.chapter, range.fromVerse, range.toVerse),
          ),
          [(63, 2, 1, 2)],
        );

        expect(
          await database.readModels.getDayActivity(
            plan.id!,
            DateTime(2026, 11, 19),
          ),
          isEmpty,
        );
      },
    );
  });

  group('plan summaries', () {
    test(
      'batches progress, today progress, and resumes with isolation',
      () async {
        final today = DateTime(2026, 11, 23);
        final first = await createPlan('First', books: [63, 64]);
        final second = await createPlan('Second', books: [8]);
        final third = await createPlan('Third', books: [65]);

        await database.markVerseRead(first.id!, 63, 1, 1);
        final session = await addSession(
          first.id!,
          DateTime(2026, 11, 23, 8),
          readSeconds: 300,
          verses: 2,
        );
        await addLog(session, 63, 1, 2, DateTime(2026, 11, 23, 8));
        await database.upsertDaySummary(first.id!, today);

        await addSession(
          second.id!,
          DateTime(2026, 11, 23, 9),
          readSeconds: 600,
          verses: 7,
        );
        await database.upsertDaySummary(second.id!, today);

        final summaries = await database.readModels.getPlanSummaries(
          today: DateTime(2026, 11, 23, 15),
        );
        expect(summaries, hasLength(3));

        final firstSummary = summaries.singleWhere(
          (plan) => plan.planId == first.id,
        );
        expect(firstSummary.totalVerses, 28);
        expect(firstSummary.versesRead, 2);
        expect(firstSummary.booksRead, 0);
        expect(firstSummary.today.verses, 2);
        expect(firstSummary.today.minutes, 5);
        expect(
          firstSummary.resumePosition,
          const Reference(bookId: 63, chapter: 1, verse: 3),
        );

        final secondSummary = summaries.singleWhere(
          (plan) => plan.planId == second.id,
        );
        expect(secondSummary.totalVerses, 85);
        expect(secondSummary.versesRead, 0);
        expect(secondSummary.today.verses, 7);
        expect(secondSummary.today.minutes, 10);
        expect(
          secondSummary.resumePosition,
          const Reference(bookId: 8, chapter: 1, verse: 1),
        );

        final thirdSummary = summaries.singleWhere(
          (plan) => plan.planId == third.id,
        );
        expect(thirdSummary.totalVerses, 25);
        expect(thirdSummary.today.empty, isTrue);
        expect(
          thirdSummary.resumePosition,
          const Reference(bookId: 65, chapter: 1, verse: 1),
        );
      },
    );

    test('returns an empty list with no plans', () async {
      expect(await database.readModels.getPlanSummaries(), isEmpty);
    });
  });

  group('session runtime', () {
    test(
      'reads session identity, start time, seconds, and day progress',
      () async {
        final plan = await createPlan('Runtime', goalValue: 5);
        final day = DateTime(2026, 11, 17);
        final session = await addSession(
          plan.id!,
          DateTime(2026, 11, 17, 9, 30),
          readSeconds: 600,
          verses: 3,
        );
        await database.upsertDaySummary(plan.id!, day);

        final runtime = (await database.readModels.getSessionRuntime(
          session.id!,
        ))!;
        expect(runtime.sessionId, session.id);
        expect(runtime.planId, plan.id);
        expect(runtime.sessionDay, day);
        expect(runtime.sessionStartTime, DateTime(2026, 11, 17, 9, 30));
        expect(runtime.sessionReadSeconds, 600);
        expect(runtime.versesToday, 3);
        expect(runtime.secondsToday, 600);
        expect(runtime.goalAlreadyReachedToday, isFalse);
        expect(runtime.dayProgress.goalValue, 5);
      },
    );

    test('returns null for a missing session', () async {
      expect(await database.readModels.getSessionRuntime(999), isNull);
    });
  });

  group('verse read states', () {
    test(
      'flags only the given session and exposes total read counts',
      () async {
        final plan = await createPlan('Verses', books: [63]);
        final session = await addSession(plan.id!, DateTime(2026, 11, 17, 9));
        final otherSession = await addSession(
          plan.id!,
          DateTime(2026, 11, 17, 10),
        );

        await addLog(session, 63, 1, 1, DateTime(2026, 11, 17, 9));
        await addLog(session, 63, 1, 2, DateTime(2026, 11, 17, 9));
        await addLog(otherSession, 63, 1, 1, DateTime(2026, 11, 17, 10));

        var states = await database.readModels.getVerseReadStates(
          session.id!,
          63,
          1,
        );
        expect(states[1]!.readCount, 2);
        expect(states[1]!.readThisSession, isTrue);
        expect(states[2]!.readCount, 1);
        expect(states[2]!.readThisSession, isTrue);
        expect(states[3]!.readCount, 0);
        expect(states[3]!.readThisSession, isFalse);

        states = await database.readModels.getVerseReadStates(
          otherSession.id!,
          63,
          1,
        );
        expect(states[1]!.readCount, 2);
        expect(states[1]!.readThisSession, isTrue);
        expect(states[2]!.readThisSession, isFalse);
      },
    );

    test('returns an empty map for a missing session', () async {
      expect(await database.readModels.getVerseReadStates(999, 63, 1), isEmpty);
    });
  });
}
