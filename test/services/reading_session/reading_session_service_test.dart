import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/services/reading_session/reading_plan_service.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late ReadingSessionService sessionService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());

    database = ReadingSessionDatabase(
      databaseName: 'reading_session_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDatabase(database);
    sessionService = ReadingSessionService.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  Future<int> startPlan(int planId) async {
    final snapshot = await sessionService.startSession(planId);
    return snapshot!.progress.sessionId;
  }

  test('starts a session and returns a static plan config', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Session Service Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63, 64},
    );

    final snapshot = await sessionService.startSession(plan.id!);

    expect(snapshot, isNotNull);
    final config = snapshot!.config;
    expect(config.planId, plan.id);
    expect(config.planName, 'Session Service Test');
    expect(config.collectionId, 1);
    expect(config.dailyGoal.type, GoalType.verses);
    expect(config.dailyGoal.value, 15);
    expect(config.books.map((book) => book.bookId), [63, 64]);
    expect(config.bookIds, {63, 64});
    expect(config.totalChapters, 2);
    expect(config.totalVerses, 28);
    expect(() => config.books.add(config.books.first), throwsUnsupportedError);

    expect(snapshot.progress.versesToday, 0);
    expect(snapshot.progress.secondsToday, 0);
    expect(snapshot.progress.goalAlreadyReachedToday, isFalse);
    expect(snapshot.progress.sessionDay, isNotNull);
    expect(snapshot.progress.sessionId, isPositive);
  });

  test('returns null when the plan does not exist', () async {
    expect(await sessionService.startSession(999), isNull);
  });

  test('starts a session from a plan id and clears it on end', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Session Service State Test',
      collectionId: 1,
      goalType: GoalType.minutes,
      goalValue: 20,
      selectedBookIds: {19},
    );

    final viewModel = ReadingSessionViewModel.withService(sessionService);

    expect(viewModel.planConfig, isNull);
    expect(viewModel.hasActiveSession, isFalse);

    await viewModel.startSession(plan.id!);

    expect(viewModel.hasActiveSession, isTrue);
    expect(viewModel.planConfig?.planId, plan.id);
    expect(viewModel.planConfig?.dailyGoal.type, GoalType.minutes);
    expect(viewModel.planConfig?.dailyGoal.value, 20);

    await viewModel.endSession();

    expect(viewModel.planConfig, isNull);
    expect(viewModel.hasActiveSession, isFalse);

    viewModel.dispose();
  });

  test('throws when starting a session for an unknown plan', () async {
    final viewModel = ReadingSessionViewModel.withService(sessionService);

    await expectLater(viewModel.startSession(999), throwsA(isA<StateError>()));
    expect(viewModel.hasActiveSession, isFalse);

    viewModel.dispose();
  });

  test(
    'view model ends the active session before starting a new one',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Restart Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 10,
        selectedBookIds: {63},
      );

      final viewModel = ReadingSessionViewModel.withService(sessionService);

      await viewModel.startSession(plan.id!);
      final firstSessionId = viewModel.sessionId;

      await viewModel.startSession(plan.id!);
      final secondSessionId = viewModel.sessionId;

      expect(firstSessionId, isNotNull);
      expect(secondSessionId, isNotNull);
      expect(secondSessionId, isNot(firstSessionId));

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessions = await database.getSessionsForDate(today, plan.id!);
      expect(sessions, hasLength(2));
      expect(
        sessions.firstWhere((session) => session.id == firstSessionId).endTime,
        isNotNull,
      );

      viewModel.dispose();
    },
  );

  test(
    'marks a verse and returns fresh chapter counts with progress',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Mark Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final sessionId = await startPlan(plan.id!);
      final result = (await sessionService.markVerseAsRead(
        sessionId,
        63,
        1,
        1,
      ))!;

      expect(result.verseReadCounts[1], 1);
      expect(result.progress.versesToday, 1);
      expect(result.bookCompleted, isNull);
      expect(result.progress.asOf, isNotNull);

      final counts = await sessionService.getVerseReadCounts(sessionId, 63, 1);
      expect(counts[1], 1);
    },
  );

  test('enforces maximumReadCount and reset clears session logs', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Reset Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63},
    );

    final sessionId = await startPlan(plan.id!);
    for (int i = 0; i < ReadingSessionService.maximumReadCount; i++) {
      await sessionService.markVerseAsRead(sessionId, 63, 1, 1);
    }

    final capped = (await sessionService.markVerseAsRead(sessionId, 63, 1, 1))!;
    expect(capped.verseReadCounts[1], ReadingSessionService.maximumReadCount);
    expect(capped.progress.versesToday, ReadingSessionService.maximumReadCount);

    final reset = (await sessionService.resetVerseProgress(
      sessionId,
      63,
      1,
      1,
    ))!;
    expect(reset.verseReadCounts[1], 0);
    expect(reset.progress.versesToday, 0);
  });

  test('reports book completion with the next resume position', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Completion Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63, 64},
    );

    final sessionId = await startPlan(plan.id!);

    VerseReadResult? result;
    for (int verse = 1; verse <= 13; verse++) {
      result = await sessionService.markVerseAsRead(sessionId, 63, 1, verse);
    }

    final event = result!.bookCompleted;
    expect(event, isNotNull);
    expect(event!.completedBookId, 63);
    expect(event.nextBookId, 64);
    expect(event.resumePosition?.bookId, 64);
    expect(event.resumePosition?.chapter, 1);
    expect(event.resumePosition?.verse, 1);
  });

  test(
    'celebrates the goal once per day and suppresses it on restart',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Goal Celebration Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 2,
        selectedBookIds: {63},
      );

      final viewModel = ReadingSessionViewModel.withService(sessionService);
      await viewModel.startSession(plan.id!);

      await viewModel.markVerseAsRead(63, 1, 1);
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.markVerseAsRead(63, 1, 2);
      expect(viewModel.goalReachedNotifier.value, isTrue);

      await viewModel.endSession();
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.startSession(plan.id!);
      expect(viewModel.session?.goalAlreadyReachedToday, isTrue);

      await viewModel.markVerseAsRead(63, 1, 3);
      expect(viewModel.goalReachedNotifier.value, isFalse);

      viewModel.dispose();
    },
  );

  test('heartbeat extends the session and end closes it', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Heartbeat Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {63},
    );

    final sessionId = await startPlan(plan.id!);
    await Future<void>.delayed(const Duration(seconds: 1));

    final progress = (await sessionService.heartbeat(sessionId))!;
    expect(progress.secondsToday, greaterThanOrEqualTo(1));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final beforeEnd = (await database.getSessionsForDate(
      today,
      plan.id!,
    )).single.endTime;
    expect(beforeEnd, isNotNull);

    await sessionService.endSession(sessionId);

    final sessions = await database.getSessionsForDate(today, plan.id!);
    expect(sessions, hasLength(1));
    expect(sessions.single.endTime, isNotNull);

    final summary = await database.getDaySummariesBetween(
      plan.id!,
      today,
      today,
    );
    expect(summary, hasLength(1));
    expect(summary.single.rsSeconds, greaterThanOrEqualTo(1));
  });

  test('returns null for actions on a missing session', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'Missing Session Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {63},
    );

    final sessionId = await startPlan(plan.id!);
    await sessionService.endSession(sessionId);

    expect(await sessionService.heartbeat(-1), isNull);
    expect(await sessionService.markVerseAsRead(-1, 63, 1, 1), isNull);
    expect(await sessionService.resetVerseProgress(-1, 63, 1, 1), isNull);
    expect(await sessionService.getVerseReadCounts(-1, 63, 1), isEmpty);
  });
}
