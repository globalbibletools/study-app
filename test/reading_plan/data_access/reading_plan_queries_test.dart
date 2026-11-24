import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_plan_queries_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    await _deleteAllPlans(database);
  });

  tearDown(() {
    database.dispose();
  });

  Future<int> createPlan(
    String name, {
    List<int> books = const [63],
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    bool bookmark = false,
    bool materialize = true,
    DateTime? createdAt,
  }) async {
    var planId = await database.readingPlans.commit(
      repo.ReadingPlan(
        id: 0,
        planName: name,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        goalType: goalType,
        goalValue: goalValue,
        isBookmarked: bookmark,
        bookIds: books,
      ),
    );
    if (materialize) {
      await database.verseState.materialize(planId);
    }
    return planId;
  }

  Future<Session> addSession(
    int planId,
    DateTime dateTime, {
    int readSeconds = 0,
    int verses = 0,
    bool isManual = false,
  }) {
    return database.session.commit(
      Session(
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
    Session session,
    int bookId,
    int chapter,
    int verse,
    DateTime dateTime,
  ) async {
    await database.sessionLog.append(
      SessionLogEntry(
        sessionId: session.id!,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        dateTime: dateTime,
        readingPlanId: session.readingPlanId,
      ),
    );
    await database.verseState.markRead(
      session.readingPlanId,
      bookId,
      chapter,
      verse,
      timestamp: dateTime,
    );
  }

  group('plan configs', () {
    test(
      'reads identity, ordered books, normalized goals, and bookmarks',
      () async {
        final first = await createPlan(
          'First',
          books: [64, 63],
          goalType: GoalType.minutes,
          goalValue: 20,
          bookmark: true,
          createdAt: DateTime(2026, 1, 1),
        );
        final second = await createPlan(
          'Second',
          books: [8],
          createdAt: DateTime(2026, 1, 2),
        );

        final summaries = await database.queries.getPlanSummaries(
          today: DateTime(2026, 11, 23),
        );
        expect(summaries.map((summary) => summary.planId), [first, second]);
        expect(summaries.first.isBookmarked, isTrue);

        final config = (await database.queries.getPlanConfig(first))!;
        expect(config.planName, 'First');
        expect(config.dailyGoal.type, GoalType.minutes);
        expect(config.dailyGoal.value, 20);
        expect(config.bookIds, [64, 63]);

        expect(await database.queries.getPlanConfig(999), isNull);
        expect(await database.queries.getPlanSummary(999), isNull);
      },
    );

    test('normalizes legacy stored goal type strings', () async {
      final planId = await createPlan('Legacy');

      await database.transaction(
        (txn) => txn.update(
          'reading_plan',
          {'goal_type': 'M'},
          where: 'id = ?',
          whereArgs: [planId],
        ),
      );

      final config = (await database.queries.getPlanConfig(planId))!;
      expect(config.dailyGoal.type, GoalType.minutes);
      expect(config.dailyGoal.value, 10);
    });

    test('returns an empty list with no plans', () async {
      expect(await database.queries.getPlanSummaries(), isEmpty);
    });
  });

  group('plan progress', () {
    test(
      'uses expected inventory totals even when books are unmaterialized',
      () async {
        final planId = await createPlan(
          'Unmaterialized',
          books: [63, 64],
          materialize: false,
        );
        await database.verseState.materialize(planId, bookIds: {63});
        await database.verseState.markRead(planId, 63, 1, 1);
        await database.verseState.markRead(planId, 63, 1, 2);

        final progress = (await database.queries.getPlanSummary(
          planId,
        ))!.progress;
        expect(progress.totalVerses, 28);
        expect(progress.versesRead, 2);
        expect(progress.bookProgress[63]!.totalVerses, 13);
        expect(progress.bookProgress[63]!.versesRead, 2);
        expect(progress.bookProgress[64]!.totalVerses, 15);
        expect(progress.bookProgress[64]!.versesRead, 0);
        expect(progress.booksRead, 0);
        expect(progress.isComplete, isFalse);
      },
    );

    test('reports book and whole-plan completion', () async {
      final single = await createPlan('Single', books: [63]);
      for (int verse = 1; verse <= 13; verse++) {
        await database.verseState.markRead(single, 63, 1, verse);
      }

      var progress = (await database.queries.getPlanSummary(single))!.progress;
      expect(progress.booksRead, 1);
      expect(progress.isComplete, isTrue);
      expect(progress.bookProgress[63]!.isComplete, isTrue);

      final multi = await createPlan('Multi', books: [63, 64]);
      await database.verseState.materialize(multi);
      for (int verse = 1; verse <= 13; verse++) {
        await database.verseState.markRead(multi, 63, 1, verse);
      }
      progress = (await database.queries.getPlanSummary(multi))!.progress;
      expect(progress.booksRead, 1);
      expect(progress.isComplete, isFalse);
    });

    test('resume positions follow the latest log in plan order', () async {
      final planId = await createPlan('Resume', books: [63, 64]);
      final first = await addSession(planId, DateTime(2026, 5, 1, 9));
      await addLog(first, 63, 1, 5, DateTime(2026, 5, 1, 9));
      final second = await addSession(planId, DateTime(2026, 5, 2, 9));
      await addLog(second, 64, 1, 2, DateTime(2026, 5, 2, 9));

      var summary = (await database.queries.getPlanSummary(planId))!;
      expect(
        summary.resumePosition,
        const Reference(bookId: 64, chapter: 1, verse: 3),
      );

      await addLog(second, 64, 1, 15, DateTime(2026, 5, 2, 10));
      summary = (await database.queries.getPlanSummary(planId))!;
      expect(summary.resumePosition, isNull);
      expect(summary.isComplete, isFalse);
    });

    test('resumeTarget falls back to the first plan book', () async {
      final planId = await createPlan('Fallback', books: [64, 63]);
      final summary = (await database.queries.getPlanSummary(planId))!;

      expect(
        summary.resumeTarget,
        const Reference(bookId: 64, chapter: 1, verse: 1),
      );
    });

    test(
      'plan resume advances to the next verse even when that verse is read',
      () async {
        final planId = await createPlan('Reread', books: [63, 64]);
        final session = await addSession(planId, DateTime(2026, 5, 1, 9));
        await addLog(session, 63, 1, 5, DateTime(2026, 5, 1, 9));
        await database.verseState.markRead(planId, 63, 1, 6);

        final summary = (await database.queries.getPlanSummary(planId))!;

        expect(
          summary.resumePosition,
          const Reference(bookId: 63, chapter: 1, verse: 6),
        );
      },
    );

    test(
      'resume skips verse numbers missing from the chapter inventory',
      () async {
        // The log points at Matthew 16:2, whose inventory skips verse 3, so
        // the resume position must land on the next verse that exists.
        database.dispose();
        database = ReadingSessionDatabase.withDependencies(
          databaseName: 'reading_plan_queries_gap_test.db',
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

        final planId = await createPlan('Gap', books: [40]);
        final session = await addSession(planId, DateTime(2026, 5, 1, 10));
        await addLog(session, 40, 16, 2, DateTime(2026, 5, 1, 10));

        final summary = (await database.queries.getPlanSummary(planId))!;

        expect(
          summary.resumePosition,
          const Reference(bookId: 40, chapter: 16, verse: 4),
        );
      },
    );
  });

  group('day progress', () {
    test('distinguishes a missing summary from a zero-activity row', () async {
      final planId = await createPlan('Day', goalValue: 5);
      final day = DateTime(2026, 11, 5);

      var progress = (await database.queries.getPlanSummary(
        planId,
        today: day,
      ))!.today;
      expect(progress.hasSummary, isFalse);
      expect(progress.hasActivity, isFalse);

      await database.daySummary.upsert(planId, day);
      progress = (await database.queries.getPlanSummary(
        planId,
        today: day,
      ))!.today;
      expect(progress.hasSummary, isTrue);
      expect(progress.seconds, 0);
      expect(progress.verses, 0);
      expect(progress.hasActivity, isFalse);
      expect(progress.goalReached, isFalse);
      expect(progress.goal!.value, 5);
    });

    test('reads stored totals and the stored goal snapshot', () async {
      final planId = await createPlan('Day', goalValue: 5);
      final day = DateTime(2026, 11, 5);
      await addSession(
        planId,
        DateTime(2026, 11, 5, 9),
        readSeconds: 750,
        verses: 7,
      );
      await database.daySummary.upsert(planId, day);

      final progress = (await database.queries.getPlanSummary(
        planId,
        today: day,
      ))!.today;
      expect(progress.seconds, 750);
      expect(progress.verses, 7);
      expect(progress.goalReached, isTrue);
      expect(progress.goal!.type, GoalType.verses);
      expect(progress.goal!.value, 5);
      expect(progress.minutes, 12.5);

      final plan = (await database.readingPlans.getById(planId))!;
      await database.readingPlans.commit(plan.copyWith(goalValue: 20));

      final afterGoalChange = (await database.queries.getPlanSummary(
        planId,
        today: day,
      ))!.today;
      expect(afterGoalChange.goal!.value, 5);
      expect(afterGoalChange.goalReached, isTrue);
    });
  });

  group('month day progress', () {
    test('returns a sparse map of only the days with summaries', () async {
      final planId = await createPlan('Month', goalValue: 5);
      await addSession(
        planId,
        DateTime(2026, 11, 5, 9),
        readSeconds: 750,
        verses: 7,
      );
      await database.daySummary.upsert(planId, DateTime(2026, 11, 5));
      await database.daySummary.upsert(planId, DateTime(2026, 11, 20));
      await database.daySummary.upsert(planId, DateTime(2026, 12, 1));

      final month = await database.queries.getMonthDayProgress(
        planId,
        DateTime(2026, 11, 1),
      );

      expect(month.keys, [5, 20]);
      expect(month[5]!.day, DateTime(2026, 11, 5));
      expect(month[5]!.verses, 7);
      expect(month[5]!.minutes, 12.5);
      expect(month[5]!.hasActivity, isTrue);
      expect(month[5]!.goal!.value, 5);
      expect(month[20]!.day, DateTime(2026, 11, 20));
      expect(month[20]!.hasActivity, isFalse);
    });

    test('includes leap days', () async {
      final planId = await createPlan('Leap');
      await database.daySummary.upsert(planId, DateTime(2028, 2, 29));

      final month = await database.queries.getMonthDayProgress(
        planId,
        DateTime(2028, 2, 1),
      );

      expect(month.keys, [29]);
      expect(month[29]!.day, DateTime(2028, 2, 29));
    });

    test('maps November daylight saving days one to one', () async {
      // November 2026 crosses the DST fallback; every day must still map
      // to exactly its own calendar cell.
      final planId = await createPlan('DST', goalValue: 5);
      final day = DateTime(2026, 11, 5);
      await addSession(
        planId,
        DateTime(2026, 11, 5, 10),
        readSeconds: 750,
        verses: 7,
      );
      await database.daySummary.upsert(planId, day);

      final month = await database.queries.getMonthDayProgress(
        planId,
        DateTime(2026, 11, 1),
      );

      expect(month.keys, [5]);
      expect(month[5]!.day, day);
      expect(month[5]!.verses, 7);
      expect(month[5]!.minutes, 12.5);
      expect(month[5]!.goalReached, isTrue);
      expect(month.containsKey(6), isFalse);
    });
  });

  group('day activity', () {
    test(
      'returns only the plan and day, folds ranges, and totals sessions',
      () async {
        final planId = await createPlan('Activity', books: [63, 64]);
        final otherPlanId = await createPlan('Other', books: [8]);
        final day = DateTime(2026, 11, 17);

        final first = await addSession(planId, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 1, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 2, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 3, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 5, DateTime(2026, 11, 17, 9));
        await addLog(first, 64, 1, 1, DateTime(2026, 11, 17, 9));

        final second = await addSession(
          planId,
          DateTime(2026, 11, 17, 14),
          readSeconds: 300,
          verses: 2,
        );
        await addLog(second, 63, 2, 1, DateTime(2026, 11, 17, 14));
        await addLog(second, 63, 2, 2, DateTime(2026, 11, 17, 14));

        final manual = await addSession(
          planId,
          DateTime(2026, 11, 17, 16),
          readSeconds: 120,
          verses: 4,
          isManual: true,
        );

        final otherSession = await addSession(
          otherPlanId,
          DateTime(2026, 11, 17, 10),
        );
        await addLog(otherSession, 8, 1, 1, DateTime(2026, 11, 17, 10));

        final otherDaySession = await addSession(
          planId,
          DateTime(2026, 11, 18, 9),
        );
        await addLog(otherDaySession, 63, 1, 1, DateTime(2026, 11, 18, 9));

        final activity = await database.queries.getDayActivity(planId, day);

        expect(activity.day, day);
        expect(activity.sessions.map((session) => session.sessionId), [
          first.id,
          second.id,
          manual.id,
        ]);
        expect(
          activity.sessions.first.ranges.map(
            (range) =>
                (range.bookId, range.chapter, range.fromVerse, range.toVerse),
          ),
          [(63, 1, 1, 3), (63, 1, 5, 5), (64, 1, 1, 1)],
        );
        expect(
          activity.sessions[1].ranges.map(
            (range) =>
                (range.bookId, range.chapter, range.fromVerse, range.toVerse),
          ),
          [(63, 2, 1, 2)],
        );
        expect(activity.sessions.last.isManual, isTrue);
        expect(activity.sessions.last.ranges, isEmpty);
        expect(activity.totalSeconds, 420);
        expect(activity.totalVerses, 6);
        expect(activity.totalMinutes, 7);
      },
    );

    test('returns an empty activity for a day with no sessions', () async {
      final planId = await createPlan('Activity');

      final activity = await database.queries.getDayActivity(
        planId,
        DateTime(2026, 11, 19),
      );

      expect(activity.sessions, isEmpty);
      expect(activity.totalSeconds, 0);
      expect(activity.totalVerses, 0);
    });
  });

  group('session runtime', () {
    test(
      'reads session identity and the same daily numbers as the summary',
      () async {
        final planId = await createPlan('Runtime', goalValue: 5);
        final day = DateTime(2026, 11, 17);
        final session = await addSession(
          planId,
          DateTime(2026, 11, 17, 9, 30),
          readSeconds: 600,
          verses: 3,
        );
        await database.daySummary.upsert(planId, day);

        final runtime = (await database.queries.getSessionRuntime(
          session.id!,
        ))!;
        expect(runtime.sessionId, session.id);
        expect(runtime.planId, planId);
        expect(runtime.sessionDay, day);
        expect(runtime.sessionStartTime, DateTime(2026, 11, 17, 9, 30));
        expect(runtime.sessionReadSeconds, 600);
        expect(runtime.versesToday, 3);
        expect(runtime.secondsToday, 600);
        expect(runtime.goalAlreadyReachedToday, isFalse);
        expect(runtime.dayProgress.goal!.value, 5);

        final summary = (await database.queries.getPlanSummary(
          planId,
          today: day,
        ))!.today;
        expect(runtime.versesToday, summary.verses);
        expect(runtime.secondsToday, summary.seconds);
      },
    );

    test('returns null for a missing session', () async {
      expect(await database.queries.getSessionRuntime(999), isNull);
    });
  });

  group('verse read states', () {
    test(
      'flags only the given session and exposes total read counts',
      () async {
        final planId = await createPlan('Verses', books: [63]);
        final first = await addSession(planId, DateTime(2026, 11, 17, 9));
        final second = await addSession(planId, DateTime(2026, 11, 17, 10));

        await addLog(first, 63, 1, 1, DateTime(2026, 11, 17, 9));
        await addLog(first, 63, 1, 2, DateTime(2026, 11, 17, 9));
        await addLog(second, 63, 1, 1, DateTime(2026, 11, 17, 10));

        var states = await database.queries.getVerseReadStates(
          first.id!,
          63,
          1,
        );
        expect(states[1]!.readCount, 2);
        expect(states[1]!.readThisSession, isTrue);
        expect(states[2]!.readCount, 1);
        expect(states[2]!.readThisSession, isTrue);
        expect(states[3]!.readCount, 0);
        expect(states[3]!.readThisSession, isFalse);

        states = await database.queries.getVerseReadStates(second.id!, 63, 1);
        expect(states[1]!.readCount, 2);
        expect(states[1]!.readThisSession, isTrue);
        expect(states[2]!.readThisSession, isFalse);
      },
    );

    test('returns an empty map for a missing session', () async {
      expect(await database.queries.getVerseReadStates(999, 63, 1), isEmpty);
    });
  });

  group('plan summaries', () {
    test('batch reads match the individual summary reads', () async {
      final today = DateTime(2026, 11, 23);
      final first = await createPlan(
        'First',
        books: [63, 64],
        bookmark: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final second = await createPlan(
        'Second',
        books: [8],
        createdAt: DateTime(2026, 1, 2),
      );

      final firstSession = await addSession(
        first,
        DateTime(2026, 11, 23, 8),
        readSeconds: 300,
        verses: 2,
      );
      await addLog(firstSession, 63, 1, 2, DateTime(2026, 11, 23, 8));
      await database.daySummary.upsert(first, today);
      await addSession(
        second,
        DateTime(2026, 11, 23, 9),
        readSeconds: 600,
        verses: 7,
      );
      await database.daySummary.upsert(second, today);

      final summaries = await database.queries.getPlanSummaries(today: today);
      expect(summaries, hasLength(2));

      for (final summary in summaries) {
        final individual = (await database.queries.getPlanSummary(
          summary.planId,
          today: today,
        ))!;
        expect(summary.totalVerses, individual.totalVerses);
        expect(summary.versesRead, individual.versesRead);
        expect(summary.booksRead, individual.booksRead);
        expect(summary.today.seconds, individual.today.seconds);
        expect(summary.today.verses, individual.today.verses);
        expect(summary.resumePosition, individual.resumePosition);
      }

      final firstSummary = summaries.singleWhere(
        (summary) => summary.planId == first,
      );
      expect(firstSummary.totalVerses, 28);
      expect(firstSummary.versesRead, 1);
      expect(firstSummary.today.verses, 2);
      expect(firstSummary.today.minutes, 5);
      expect(
        firstSummary.resumePosition,
        const Reference(bookId: 63, chapter: 1, verse: 3),
      );

      final secondSummary = summaries.singleWhere(
        (summary) => summary.planId == second,
      );
      expect(secondSummary.totalVerses, 85);
      expect(secondSummary.versesRead, 0);
      expect(secondSummary.today.verses, 7);
      expect(secondSummary.today.hasActivity, isTrue);
    });
  });
}

Future<void> _deleteAllPlans(ReadingSessionDatabase database) async {
  await database.transaction((txn) async {
    final rows = await txn.query('reading_plan', columns: ['id']);
    for (final row in rows) {
      final planId = row['id'] as int;
      await database.sessionLog.deleteForPlanId(planId, executor: txn);
      await database.session.deleteForPlanId(planId, executor: txn);
      await database.daySummary.deleteForPlanId(planId, executor: txn);
      await database.verseState.deleteForPlanId(planId, executor: txn);
      await database.readingPlans.delete(planId, executor: txn);
    }
  });
}
