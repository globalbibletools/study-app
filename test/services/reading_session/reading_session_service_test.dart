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

  Future<VerseReadResult?> setVerseRead(
    int sessionId,
    VerseReadOptions options,
  ) {
    return sessionService.setVerseRead(sessionId, options, readSeconds: 0);
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
    'marks a verse and returns fresh chapter states with progress',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Mark Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final sessionId = await startPlan(plan.id!);
      final result = (await setVerseRead(
        sessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;

      expect(result.verseReadStates[1]?.readCount, 1);
      expect(result.verseReadStates[1]?.readThisSession, isTrue);
      expect(result.progress.versesToday, 1);
      expect(result.bookCompleted, isNull);
      expect(result.progress.asOf, isNotNull);

      final states = await sessionService.getVerseReadStates(sessionId, 63, 1);
      expect(states[1]?.readCount, 1);
      expect(states[1]?.readThisSession, isTrue);
    },
  );

  test(
    'reading a verse twice in one session is a no-op the second time',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Idempotent Read Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final sessionId = await startPlan(plan.id!);
      final first = (await setVerseRead(
        sessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;
      final second = (await setVerseRead(
        sessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;

      expect(first.verseReadStates[1]?.readCount, 1);
      expect(second.verseReadStates[1]?.readCount, 1);
      expect(second.verseReadStates[1]?.readThisSession, isTrue);
      expect(second.progress.versesToday, 1);
    },
  );

  test(
    'unchecking removes only the current session log and decrements counts',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Uncheck Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final firstSessionId = await startPlan(plan.id!);
      await setVerseRead(firstSessionId, _readOptions(63, 1, 1, read: true));
      await sessionService.endSession(firstSessionId, readSeconds: 0);

      final secondSessionId = await startPlan(plan.id!);
      final checked = (await setVerseRead(
        secondSessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;
      expect(checked.verseReadStates[1]?.readCount, 2);
      expect(checked.progress.versesToday, 2);

      final unchecked = (await setVerseRead(
        secondSessionId,
        _readOptions(63, 1, 1, read: false),
      ))!;

      expect(unchecked.verseReadStates[1]?.readCount, 1);
      expect(unchecked.verseReadStates[1]?.readThisSession, isFalse);
      expect(unchecked.progress.versesToday, 1);
      expect(unchecked.bookCompleted, isNull);

      expect(await database.getRsLogForSession(firstSessionId), hasLength(1));
      expect(await database.getRsLogForSession(secondSessionId), isEmpty);
    },
  );

  test('unchecking a verse not read in this session is a no-op', () async {
    final plan = await planService.saveReadingPlan(
      planName: 'No-op Uncheck Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
    );

    final firstSessionId = await startPlan(plan.id!);
    await setVerseRead(firstSessionId, _readOptions(63, 1, 1, read: true));
    await sessionService.endSession(firstSessionId, readSeconds: 0);

    final secondSessionId = await startPlan(plan.id!);
    final before = (await database.getSessionById(secondSessionId))!;

    final result = (await setVerseRead(
      secondSessionId,
      _readOptions(63, 1, 1, read: false),
    ))!;

    expect(result.verseReadStates[1]?.readCount, 1);
    expect(result.verseReadStates[1]?.readThisSession, isFalse);
    expect(result.progress.versesToday, 1);

    final after = (await database.getSessionById(secondSessionId))!;
    expect(after.endTime, before.endTime);
  });

  test(
    'a verse read before midnight is unchecked in the new day session',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Rollover Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final oldSession = await database.insertSession(
        RsSession(
          rsDate: yesterday,
          startTime: yesterday.add(const Duration(hours: 9)),
          endTime: yesterday.add(const Duration(hours: 9, minutes: 5)),
          readSeconds: 300,
          verses: 1,
          readingPlanId: plan.id!,
        ),
      );
      await database.markVerseRead(plan.id!, 63, 1, 1);
      await database.insertLog(
        RsLog(
          sessionId: oldSession.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          dateTime: yesterday.add(const Duration(hours: 9)),
          readingPlanId: plan.id!,
        ),
      );

      final rollover = (await sessionService.rolloverSession(
        oldSession.id!,
        at: now,
        oldReadSeconds: 300,
        newReadSeconds: 0,
      ))!;

      final newSessionId = rollover.sessionId;
      expect(newSessionId, isNot(oldSession.id));
      expect(rollover.versesToday, 0);
      expect(rollover.secondsToday, 0);

      final unchecked = (await setVerseRead(
        newSessionId,
        _readOptions(63, 1, 1, read: false),
      ))!;
      expect(unchecked.verseReadStates[1]?.readCount, 1);
      expect(unchecked.verseReadStates[1]?.readThisSession, isFalse);
      expect(unchecked.progress.versesToday, 0);
      expect(unchecked.bookCompleted, isNull);
      expect(await database.getRsLogForSession(oldSession.id!), hasLength(1));

      final checked = (await setVerseRead(
        newSessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;
      expect(checked.verseReadStates[1]?.readCount, 2);
      expect(checked.verseReadStates[1]?.readThisSession, isTrue);
      expect(checked.progress.versesToday, 1);
      expect(await database.getRsLogForSession(oldSession.id!), hasLength(1));
      expect(await database.getRsLogForSession(newSessionId), hasLength(1));
    },
  );

  test(
    'session operations reject stale sessions until an explicit rollover',
    () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Stale Session Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final oldSession = await database.insertSession(
        RsSession(
          rsDate: yesterday,
          startTime: yesterday.add(const Duration(hours: 9)),
          endTime: yesterday.add(const Duration(hours: 9, minutes: 5)),
          readSeconds: 300,
          verses: 0,
          readingPlanId: plan.id!,
        ),
      );

      await expectLater(
        sessionService.heartbeat(oldSession.id!, readSeconds: 300),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        setVerseRead(oldSession.id!, _readOptions(63, 1, 1, read: true)),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        sessionService.endSession(oldSession.id!, readSeconds: 300),
        throwsA(isA<StateError>()),
      );

      final rolled = (await sessionService.rolloverSession(
        oldSession.id!,
        at: now,
        oldReadSeconds: 300,
        newReadSeconds: 0,
      ))!;

      expect(rolled.sessionId, isNot(oldSession.id));
      final old = (await database.getSessionById(oldSession.id!))!;
      expect(old.readSeconds, 300);
      expect(old.endTime, yesterday.add(const Duration(days: 1, seconds: -1)));

      final progress = (await sessionService.heartbeat(
        rolled.sessionId,
        readSeconds: 0,
      ))!;
      expect(progress.sessionId, rolled.sessionId);
    },
  );

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
      result = await setVerseRead(sessionId, _readOptions(63, 1, verse));
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

      await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.setVerseRead(_readOptions(63, 1, 2, read: true));
      expect(viewModel.goalReachedNotifier.value, isTrue);

      await viewModel.endSession();
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.startSession(plan.id!);
      expect(viewModel.session?.goalAlreadyReachedToday, isTrue);

      await viewModel.setVerseRead(_readOptions(63, 1, 3, read: true));
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

    final progress = (await sessionService.heartbeat(
      sessionId,
      readSeconds: 1,
    ))!;
    expect(progress.secondsToday, greaterThanOrEqualTo(1));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final beforeEnd = (await database.getSessionsForDate(
      today,
      plan.id!,
    )).single.endTime;
    expect(beforeEnd, isNotNull);

    await sessionService.endSession(sessionId, readSeconds: 0);

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
    await sessionService.endSession(sessionId, readSeconds: 0);

    expect(await sessionService.heartbeat(-1, readSeconds: 0), isNull);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: true)), isNull);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: false)), isNull);
    expect(await sessionService.getVerseReadStates(-1, 63, 1), isEmpty);
  });
}
