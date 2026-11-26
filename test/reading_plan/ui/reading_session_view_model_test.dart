import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';
import '../../fixtures/fake_navigation_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;
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

    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_session_view_model_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);
    sessionService = ReadingSessionService.withDatabase(database);
    navigationViewModel = FakeNavigationViewModel();
  });

  tearDown(() {
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  ReadingSessionViewModel newViewModel() {
    return ReadingSessionViewModel.withDependencies(
      service: sessionService,
      queries: database.queries,
      navigationViewModel: navigationViewModel,
    );
  }

  group('session lifecycle', () {
    test('starts a session from a plan id and clears it on end', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Session State Test',
        goalType: GoalType.minutes,
        goalValue: 20,
        bookIds: [19],
      );

      final viewModel = newViewModel();

      expect(viewModel.planConfig, isNull);
      expect(viewModel.hasActiveSession, isFalse);

      await viewModel.startSession(planId);

      expect(viewModel.hasActiveSession, isTrue);
      expect(viewModel.planConfig?.planId, planId);
      expect(viewModel.planConfig?.dailyGoal.type, GoalType.minutes);
      expect(viewModel.planConfig?.dailyGoal.value, 20);
      expect(navigationViewModel.navigatedReferences, [
        const Reference(bookId: 19, chapter: 1, verse: 1),
      ]);

      await viewModel.endSession();

      expect(viewModel.planConfig, isNull);
      expect(viewModel.hasActiveSession, isFalse);

      viewModel.dispose();
    });

    test('throws when starting a session for an unknown plan', () async {
      final viewModel = newViewModel();

      await expectLater(
        viewModel.startSession(999),
        throwsA(isA<StateError>()),
      );
      expect(viewModel.hasActiveSession, isFalse);
      expect(navigationViewModel.navigatedReferences, isEmpty);

      viewModel.dispose();
    });

    test('ends the active session before starting a new one', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Restart Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63],
      );

      final viewModel = newViewModel();

      await viewModel.startSession(planId);
      final firstSessionId = viewModel.sessionId;

      await viewModel.startSession(planId);
      final secondSessionId = viewModel.sessionId;

      expect(firstSessionId, isNotNull);
      expect(secondSessionId, isNotNull);
      expect(secondSessionId, isNot(firstSessionId));

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessions = await database.session.listForDate(today, planId);
      expect(sessions, hasLength(2));
      expect(
        sessions.firstWhere((session) => session.id == firstSessionId).endTime,
        isNotNull,
      );

      viewModel.dispose();
    });

    test('navigates to the plan resume reference', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Resume Navigation Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [19],
      );
      await database.verseState.markRead(planId, 19, 1, 1);

      final now = DateTime.now();
      final session = await database.session.commit(
        Session(
          rsDate: DateTime(now.year, now.month, now.day),
          startTime: now,
          endTime: now,
          verses: 1,
          readingPlanId: planId,
        ),
      );
      await database.sessionLog.append(
        SessionLogEntry(
          sessionId: session.id!,
          bookId: 19,
          chapter: 1,
          verse: 1,
          dateTime: now,
          readingPlanId: planId,
        ),
      );

      final viewModel = newViewModel();
      await viewModel.startSession(planId);

      expect(navigationViewModel.navigatedReferences, [
        const Reference(bookId: 19, chapter: 1, verse: 2),
      ]);

      viewModel.dispose();
    });
  });

  group('goal celebration', () {
    test(
      'celebrates the goal once per day and suppresses it on restart',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Goal Celebration Test',
          goalType: GoalType.verses,
          goalValue: 2,
          bookIds: [63],
        );

        final viewModel = newViewModel();
        await viewModel.startSession(planId);

        var goalReachedCount = 0;
        final subscription = viewModel.goalReached.listen(
          (_) => goalReachedCount++,
        );
        addTearDown(subscription.cancel);

        await viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(goalReachedCount, 0);

        await viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 2,
          read: true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(goalReachedCount, 1);

        await viewModel.endSession();
        await Future<void>.delayed(Duration.zero);
        expect(goalReachedCount, 1);

        await viewModel.startSession(planId);
        expect(viewModel.sessionRuntime?.goalAlreadyReachedToday, isTrue);

        await viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 3,
          read: true,
        );
        await Future<void>.delayed(Duration.zero);
        expect(goalReachedCount, 1);

        viewModel.dispose();
      },
    );
  });

  group('book completion notifications', () {
    test(
      'completing chapter 1 of a multi-chapter book does not notify and advances the cursor to the next chapter',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Multi-Chapter Book Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [19, 20],
        );

        final viewModel = newViewModel();
        await viewModel.startSession(planId);

        int bookCompletedCount = 0;
        BookCompletedEvent? lastCompletion;
        final subscription = viewModel.bookCompleted.listen((event) {
          bookCompletedCount++;
          lastCompletion = event;
        });
        addTearDown(subscription.cancel);

        expect(getIt<BibleNavigation>().getVerseCount(19, 1), 6);
        for (int v = 1; v <= 6; v++) {
          await viewModel.setVerseRead(
            bookId: 19,
            chapter: 1,
            verse: v,
            read: true,
          );
        }

        expect(bookCompletedCount, 0);
        expect(lastCompletion, isNull);

        final stats = await database.verseState.getBookStats(planId);
        expect(stats[19]!.versesRead, 6);
        final resume = (await database.queries.getPlanSummary(
          planId,
        ))!.resumePosition;
        expect(resume, isNotNull);
        expect(resume!.bookId, 19);
        expect(resume.chapter, 2);
        expect(resume.verse, 1);

        viewModel.dispose();
      },
    );

    test(
      'checking the final verse of a book before earlier chapters does not notify',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Early Final Verse Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [19, 20],
        );

        final viewModel = newViewModel();
        await viewModel.startSession(planId);

        int bookCompletedCount = 0;
        final subscription = viewModel.bookCompleted.listen((_) {
          bookCompletedCount++;
        });
        addTearDown(subscription.cancel);

        await viewModel.setVerseRead(
          bookId: 19,
          chapter: 150,
          verse: 6,
          read: true,
        );

        expect(bookCompletedCount, 0);

        final stats = await database.verseState.getBookStats(planId);
        expect(stats[19]!.versesRead, 1);

        viewModel.dispose();
      },
    );

    test(
      'completing all verses out of order notifies on the final unread verse',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Short Epistles',
          goalType: GoalType.verses,
          goalValue: 15,
          bookIds: [63, 64],
        );

        final viewModel = newViewModel();
        await viewModel.startSession(planId);

        BookCompletedEvent? completionReceived;
        final subscription = viewModel.bookCompleted.listen((event) {
          completionReceived = event;
        });
        addTearDown(subscription.cancel);

        for (int v = 2; v <= 13; v++) {
          await viewModel.setVerseRead(
            bookId: 63,
            chapter: 1,
            verse: v,
            read: true,
          );
        }
        expect(completionReceived, isNull);

        var stats = await database.verseState.getBookStats(planId);
        expect(stats[63]!.versesRead, 12);

        await viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
        );
        await Future<void>.delayed(Duration.zero);

        expect(completionReceived?.completedBookId, 63);
        expect(completionReceived?.nextBookId, 64);
        expect(viewModel.nextResumePosition, isNotNull);
        expect(viewModel.nextResumePosition!.bookId, 64);
        expect(viewModel.nextResumePosition!.chapter, 1);
        expect(viewModel.nextResumePosition!.verse, 1);
        stats = await database.verseState.getBookStats(planId);
        expect(stats[63]!.versesRead, 13);

        viewModel.dispose();
      },
    );
  });

  group('command serialization', () {
    test('concurrent verse marks both persist', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Concurrent Marks Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63],
      );

      final viewModel = newViewModel();
      await viewModel.startSession(planId);

      final first = viewModel.setVerseRead(
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
      );
      final second = viewModel.setVerseRead(
        bookId: 63,
        chapter: 1,
        verse: 2,
        read: true,
      );

      await first;
      await second;

      final session = await database.session.getById(viewModel.sessionId!);
      expect(session!.verses, 2);
      final stats = await database.verseState.getBookStats(planId);
      expect(stats[63]!.versesRead, 2);

      viewModel.dispose();
    });

    test('ending a session waits for queued marks', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'End Waits Test',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [63],
      );

      final viewModel = newViewModel();
      await viewModel.startSession(planId);

      final mark = viewModel.setVerseRead(
        bookId: 63,
        chapter: 1,
        verse: 1,
        read: true,
      );
      final end = viewModel.endSession();

      await mark;
      await end;

      expect(viewModel.hasActiveSession, isFalse);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessions = await database.session.listForDate(today, planId);
      expect(sessions, hasLength(1));
      expect(sessions.single.verses, 1);
      expect(sessions.single.endTime, isNotNull);

      viewModel.dispose();
    });

    test(
      'dispose finishes the current command and drops pending ones',
      () async {
        final planId = await planService.saveReadingPlan(
          planName: 'Dispose Drains Test',
          goalType: GoalType.verses,
          goalValue: 10,
          bookIds: [63],
        );

        final viewModel = newViewModel();
        await viewModel.startSession(planId);
        final sessionId = viewModel.sessionId!;

        final current = viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 1,
          read: true,
        );
        final pending = viewModel.setVerseRead(
          bookId: 63,
          chapter: 1,
          verse: 2,
          read: true,
        );

        final pendingExpectation = expectLater(
          pending,
          throwsA(isA<SerialQueueClosed>()),
        );
        viewModel.dispose();

        await current;
        await pendingExpectation;

        final session = await database.session.getById(sessionId);
        expect(session!.verses, 1);
      },
    );
  });
}
