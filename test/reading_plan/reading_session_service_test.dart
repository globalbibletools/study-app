import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/session_log_repository.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
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
      databaseName: 'reading_session_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(
      database: database,
      bibleNavigation: createTestBibleNavigation(),
    );
    sessionService = ReadingSessionService.withDatabase(database);
    navigationViewModel = FakeNavigationViewModel();
  });

  ReadingSessionViewModel newViewModel() {
    return ReadingSessionViewModel.withDependencies(
      service: sessionService,
      navigationViewModel: navigationViewModel,
    );
  }

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
    final planId = await planService.saveReadingPlan(
      planName: 'Session Service Test',
      goalType: GoalType.verses,
      goalValue: 15,
      bookIds: [63, 64],
    );

    final snapshot = await sessionService.startSession(planId);

    expect(snapshot, isNotNull);
    final config = snapshot!.config;
    expect(config.planId, planId);
    expect(config.planName, 'Session Service Test');
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
    final planId = await planService.saveReadingPlan(
      planName: 'Session Service State Test',
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

    await expectLater(viewModel.startSession(999), throwsA(isA<StateError>()));
    expect(viewModel.hasActiveSession, isFalse);
    expect(navigationViewModel.navigatedReferences, isEmpty);

    viewModel.dispose();
  });

  test('navigates to the plan resume reference', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Resume Navigation Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [19],
    );
    await database.markVerseRead(planId, 19, 1, 1);

    final now = DateTime.now();
    final session = await database.insertSession(
      RsSession(
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

  test(
    'view model ends the active session before starting a new one',
    () async {
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
      final sessions = await database.getSessionsForDate(today, planId);
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
      final planId = await planService.saveReadingPlan(
        planName: 'Mark Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );

      final sessionId = await startPlan(planId);
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
      final planId = await planService.saveReadingPlan(
        planName: 'Idempotent Read Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );

      final sessionId = await startPlan(planId);
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
      final planId = await planService.saveReadingPlan(
        planName: 'Uncheck Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
      );

      final firstSessionId = await startPlan(planId);
      await setVerseRead(firstSessionId, _readOptions(63, 1, 1, read: true));
      await sessionService.endSession(firstSessionId, readSeconds: 0);

      final secondSessionId = await startPlan(planId);
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
    final planId = await planService.saveReadingPlan(
      planName: 'No-op Uncheck Test',
      goalType: GoalType.verses,
      goalValue: 5,
      bookIds: [63],
    );

    final firstSessionId = await startPlan(planId);
    await setVerseRead(firstSessionId, _readOptions(63, 1, 1, read: true));
    await sessionService.endSession(firstSessionId, readSeconds: 0);

    final secondSessionId = await startPlan(planId);
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
      final planId = await planService.saveReadingPlan(
        planName: 'Rollover Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
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
          readingPlanId: planId,
        ),
      );
      await database.markVerseRead(planId, 63, 1, 1);
      await database.sessionLog.append(
        SessionLogEntry(
          sessionId: oldSession.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          dateTime: yesterday.add(const Duration(hours: 9)),
          readingPlanId: planId,
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
      final planId = await planService.saveReadingPlan(
        planName: 'Stale Session Test',
        goalType: GoalType.verses,
        goalValue: 5,
        bookIds: [63],
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
          readingPlanId: planId,
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
    final planId = await planService.saveReadingPlan(
      planName: 'Completion Test',
      goalType: GoalType.verses,
      goalValue: 15,
      bookIds: [63, 64],
    );

    final sessionId = await startPlan(planId);

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
      final planId = await planService.saveReadingPlan(
        planName: 'Goal Celebration Test',
        goalType: GoalType.verses,
        goalValue: 2,
        bookIds: [63],
      );

      final viewModel = newViewModel();
      await viewModel.startSession(planId);

      await viewModel.setVerseRead(_readOptions(63, 1, 1, read: true));
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.setVerseRead(_readOptions(63, 1, 2, read: true));
      expect(viewModel.goalReachedNotifier.value, isTrue);

      await viewModel.endSession();
      expect(viewModel.goalReachedNotifier.value, isFalse);

      await viewModel.startSession(planId);
      expect(viewModel.session?.goalAlreadyReachedToday, isTrue);

      await viewModel.setVerseRead(_readOptions(63, 1, 3, read: true));
      expect(viewModel.goalReachedNotifier.value, isFalse);

      viewModel.dispose();
    },
  );

  test('heartbeat extends the session and end closes it', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Heartbeat Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63],
    );

    final sessionId = await startPlan(planId);
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
      planId,
    )).single.endTime;
    expect(beforeEnd, isNotNull);

    await sessionService.endSession(sessionId, readSeconds: 0);

    final sessions = await database.getSessionsForDate(today, planId);
    expect(sessions, hasLength(1));
    expect(sessions.single.endTime, isNotNull);

    final summary = await database.getDaySummariesBetween(planId, today, today);
    expect(summary, hasLength(1));
    expect(summary.single.rsSeconds, greaterThanOrEqualTo(1));
  });

  test('returns null for actions on a missing session', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Missing Session Test',
      goalType: GoalType.verses,
      goalValue: 10,
      bookIds: [63],
    );

    final sessionId = await startPlan(planId);
    await sessionService.endSession(sessionId, readSeconds: 0);

    expect(await sessionService.heartbeat(-1, readSeconds: 0), isNull);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: true)), isNull);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: false)), isNull);
    expect(await sessionService.getVerseReadStates(-1, 63, 1), isEmpty);
  });
}
