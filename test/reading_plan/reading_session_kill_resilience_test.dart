import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';
import '../fixtures/fake_navigation_view_model.dart';

VerseReadOptions _readOptions(
  int bookId,
  int chapter,
  int verse, {
  bool read = true,
}) {
  return VerseReadOptions(
    bookId: bookId,
    chapter: chapter,
    verse: verse,
    read: read,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase rsDb;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;
  late ReadingSessionViewModel viewModel;
  late FakeNavigationViewModel navigationViewModel;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }

    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    rsDb = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_session_kill_resilience_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await rsDb.resetDatabase();
    await rsDb.init();
    planService = ReadingPlanService.withDependencies(database: rsDb);
    sessionService = ReadingSessionService.withDatabase(rsDb);
    navigationViewModel = FakeNavigationViewModel();
    viewModel = ReadingSessionViewModel.withDependencies(
      service: sessionService,
      queries: rsDb.queries,
      navigationViewModel: navigationViewModel,
    );
  });

  tearDown(() async {
    await viewModel.endSession();
    viewModel.dispose();
    rsDb.dispose();
  });

  tearDownAll(() {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  Future<RsDaySummary> summaryFor(int planId, DateTime date) async {
    final summaries = await rsDb.getDaySummariesBetween(planId, date, date);
    expect(summaries, hasLength(1));
    return summaries.single;
  }

  group('kill-resilient persistence', () {
    test('ending a session without marking verses keeps the session', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Empty Session Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63],
      );

      await viewModel.startSession(planId);
      await Future<void>.delayed(const Duration(seconds: 1));
      await viewModel.endSession();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessions = await rsDb.getSessionsForDate(today, planId);
      expect(sessions, hasLength(1));
      expect(sessions.single.verses, 0);
      expect(sessions.single.endTime, isNotNull);

      final summary = await summaryFor(planId, today);
      expect(summary.rsVerses, 0);
    });

    test(
      'a killed session still carries its marks and heartbeated duration',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Kill Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        await viewModel.startSession(planId);
        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));

        await Future<void>.delayed(const Duration(seconds: 2));
        await viewModel.setVerseRead(_readOptions(63, 1, 2, read: true));
        await viewModel.setVerseRead(_readOptions(63, 1, 3, read: true));

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final killedSessions = await rsDb.getSessionsForDate(today, planId);
        expect(killedSessions, hasLength(1));
        expect(killedSessions.single.verses, 3);
        expect(killedSessions.single.endTime, isNotNull);
        expect(
          killedSessions.single.endTime!.isAfter(
            killedSessions.single.startTime,
          ),
          isTrue,
        );

        final summary = await summaryFor(planId, today);
        expect(summary.rsVerses, 3);
        expect(summary.rsSeconds, greaterThanOrEqualTo(1));

        expect(await rsDb.getVersesReadToday(planId, today), 3);
        expect(
          await rsDb.getTotalSecondsReadToday(planId, today),
          greaterThanOrEqualTo(1),
        );
      },
    );

    test(
      'mid-day goal change applies to today (including un-reaching) while past days stay frozen',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Goal Change Test',
          goalType: GoalType.verses,
          goalValue: 3,
          bookIds: [63],
        );

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        await rsDb.session.commit(
          Session(
            rsDate: yesterday,
            startTime: yesterday.add(const Duration(hours: 9)),
            endTime: yesterday.add(const Duration(hours: 9, minutes: 5)),
            readSeconds: 300,
            verses: 5,
            readingPlanId: planId,
          ),
        );
        await rsDb.daySummary.upsert(planId, yesterday);
        expect((await summaryFor(planId, yesterday)).goalReached, isTrue);

        await viewModel.startSession(planId);
        for (int v = 1; v <= 3; v++) {
          await viewModel.setVerseRead(_readOptions(63, 1, v, read: true));
        }
        expect((await summaryFor(planId, today)).goalReached, isTrue);

        await planService.saveReadingPlan(
          planId: planId,
          planName: 'Goal Change Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        await viewModel.setVerseRead(_readOptions(63, 1, 4, read: true));

        final todaysSummary = await summaryFor(planId, today);
        expect(todaysSummary.goalReached, isFalse);
        expect(todaysSummary.goalValue, 10);
        expect(todaysSummary.rsVerses, 4);

        final pastSummary = await summaryFor(planId, yesterday);
        expect(pastSummary.goalReached, isTrue);
        expect(pastSummary.goalValue, 3);
        expect(pastSummary.rsVerses, 5);
      },
    );

    test(
      'idle heartbeat refreshes the session and summary without marks',
      () async {
        final previousInterval = ReadingSessionViewModel.heartbeatInterval;
        ReadingSessionViewModel.heartbeatInterval = const Duration(seconds: 1);
        addTearDown(() {
          ReadingSessionViewModel.heartbeatInterval = previousInterval;
        });

        final planId = await planService.saveReadingPlan(
          planName: 'Idle Flush Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        await viewModel.startSession(planId);
        await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final endBefore = (await rsDb.getSessionsForDate(
          today,
          planId,
        )).single.endTime;
        final secondsBefore = (await summaryFor(planId, today)).rsSeconds;

        await Future<void>.delayed(const Duration(milliseconds: 2500));

        final endAfter = (await rsDb.getSessionsForDate(
          today,
          planId,
        )).single.endTime;
        final secondsAfter = (await summaryFor(planId, today)).rsSeconds;

        expect(endAfter!.isAfter(endBefore!), isTrue);
        expect(secondsAfter, greaterThan(secondsBefore));
      },
    );

    test(
      'pausing the timer excludes background time from the read duration',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Pause Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        await viewModel.startSession(planId);
        await Future<void>.delayed(const Duration(seconds: 2));

        await viewModel.pauseTimer();
        final pausedSeconds = viewModel.sessionSecondsNotifier.value;
        expect(pausedSeconds, greaterThanOrEqualTo(1));

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final pausedSession = (await rsDb.getSessionsForDate(
          today,
          planId,
        )).single;
        expect(pausedSession.readSeconds, greaterThanOrEqualTo(1));

        // No time is accumulated while the app is backgrounded.
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(viewModel.sessionSecondsNotifier.value, pausedSeconds);

        viewModel.resumeTimer();
        await Future<void>.delayed(const Duration(seconds: 2));
        await viewModel.endSession();

        final endedSession = (await rsDb.getSessionsForDate(
          today,
          planId,
        )).single;
        expect(
          endedSession.readSeconds,
          inInclusiveRange(pausedSeconds + 1, pausedSeconds + 3),
        );

        // The wall-clock span still includes the paused gap, but the stored
        // read duration does not.
        final wallClockSeconds = endedSession.endTime!
            .difference(endedSession.startTime)
            .inSeconds;
        expect(
          wallClockSeconds,
          greaterThanOrEqualTo(endedSession.readSeconds + 2),
        );
      },
    );

    test("today's calendar cell updates during a live session", () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Live Cell Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );

      final now = DateTime.now();
      final month = DateTime(now.year, now.month);

      final before = await rsDb.queries.getMonthDayProgress(planId, month);
      expect(before.containsKey(now.day), isFalse);

      await viewModel.startSession(planId);
      await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));

      final after = await rsDb.queries.getMonthDayProgress(planId, month);
      final todayCell = after[now.day]!;
      expect(todayCell.verses, 1);
      expect(todayCell.goalReached, isFalse);
    });
  });
}
