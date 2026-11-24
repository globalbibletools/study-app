import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

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

    database = ReadingSessionDatabase.withDependencies(
      databaseName: 'reading_session_service_test.db',
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.resetDatabase();
    await database.init();
    planService = ReadingPlanService.withDependencies(database: database);
    sessionService = ReadingSessionService.withDatabase(database);
  });

  tearDown(() {
    database.dispose();
    if (getIt.isRegistered<BibleNavigation>()) {
      getIt.unregister<BibleNavigation>();
    }
  });

  Future<int> startPlan(int planId) async {
    final sessionId = await sessionService.startSession(planId);
    return sessionId!;
  }

  Future<VerseReadResult?> setVerseRead(
    int sessionId,
    VerseReadOptions options,
  ) {
    return sessionService.setVerseRead(sessionId, options, readSeconds: 0);
  }

  Future<Map<int, VerseReadState>> statesFor(
    int sessionId,
    int bookId,
    int chapter,
  ) {
    return database.readModels.getVerseReadStates(sessionId, bookId, chapter);
  }

  Future<ReadingSessionRuntime> runtimeFor(int sessionId) async {
    return (await database.readModels.getSessionRuntime(sessionId))!;
  }

  test('starts a session and returns a static plan config', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Session Service Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63, 64},
    );

    final sessionId = await sessionService.startSession(planId);
    expect(sessionId, isPositive);

    final config = (await database.readModels.getPlanConfig(planId))!;
    expect(config.planId, planId);
    expect(config.planName, 'Session Service Test');
    expect(config.collectionId, 1);
    expect(config.dailyGoal.type, GoalType.verses);
    expect(config.dailyGoal.value, 15);
    expect(config.books.map((book) => book.bookId), [63, 64]);
    expect(config.bookIds, [63, 64]);
    final summary = (await database.readModels.getPlanSummary(planId))!;
    expect(summary.totalVerses, 28);
    expect(() => config.books.add(config.books.first), throwsUnsupportedError);

    final runtime = (await database.readModels.getSessionRuntime(sessionId!))!;
    expect(runtime.versesToday, 0);
    expect(runtime.secondsToday, 0);
    expect(runtime.goalAlreadyReachedToday, isFalse);
    expect(runtime.sessionDay, isNotNull);
    expect(runtime.sessionId, isPositive);
  });

  test('returns null when the plan does not exist', () async {
    expect(await sessionService.startSession(999), isNull);
  });

  test(
    'marks a verse and returns fresh chapter states with progress',
    () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Mark Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final sessionId = await startPlan(planId);
      final result = (await setVerseRead(
        sessionId,
        _readOptions(63, 1, 1, read: true),
      ))!;

      expect(result.bookCompleted, isNull);

      final states = await statesFor(sessionId, 63, 1);
      expect(states[1]?.readCount, 1);
      expect(states[1]?.readThisSession, isTrue);
      expect((await runtimeFor(sessionId)).versesToday, 1);
    },
  );

  test(
    'reading a verse twice in one session is a no-op the second time',
    () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Idempotent Read Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
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

      expect(first.bookCompleted, isNull);
      expect(second.bookCompleted, isNull);
      final states = await statesFor(sessionId, 63, 1);
      expect(states[1]?.readCount, 1);
      expect(states[1]?.readThisSession, isTrue);
      expect((await runtimeFor(sessionId)).versesToday, 1);
    },
  );

  test(
    'unchecking removes only the current session log and decrements counts',
    () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Uncheck Test',
        collectionId: 1,
        goalType: GoalType.verses,
        goalValue: 5,
        selectedBookIds: {63},
      );

      final firstSessionId = await startPlan(planId);
      await setVerseRead(firstSessionId, _readOptions(63, 1, 1, read: true));
      await sessionService.endSession(firstSessionId, readSeconds: 0);

      final secondSessionId = await startPlan(planId);
      await setVerseRead(secondSessionId, _readOptions(63, 1, 1, read: true));
      final checkedStates = await statesFor(secondSessionId, 63, 1);
      expect(checkedStates[1]?.readCount, 2);
      expect((await runtimeFor(secondSessionId)).versesToday, 2);

      final unchecked = (await setVerseRead(
        secondSessionId,
        _readOptions(63, 1, 1, read: false),
      ))!;

      final uncheckedStates = await statesFor(secondSessionId, 63, 1);
      expect(uncheckedStates[1]?.readCount, 1);
      expect(uncheckedStates[1]?.readThisSession, isFalse);
      expect((await runtimeFor(secondSessionId)).versesToday, 1);
      expect(unchecked.bookCompleted, isNull);

      expect(
        await database.getRsLogForSessionAndVerse(firstSessionId, 63, 1, 1),
        hasLength(1),
      );
      expect(
        await database.getRsLogForSessionAndVerse(secondSessionId, 63, 1, 1),
        isEmpty,
      );
    },
  );

  test('unchecking a verse not read in this session is a no-op', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'No-op Uncheck Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 5,
      selectedBookIds: {63},
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

    final states = await statesFor(secondSessionId, 63, 1);
    expect(states[1]?.readCount, 1);
    expect(states[1]?.readThisSession, isFalse);
    expect((await runtimeFor(secondSessionId)).versesToday, 1);
    expect(result.bookCompleted, isNull);

    final after = (await database.getSessionById(secondSessionId))!;
    expect(after.endTime, before.endTime);
  });

  test(
    'a verse read before midnight is unchecked in the new day session',
    () async {
      final planId = await planService.saveReadingPlan(
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
          readingPlanId: planId,
        ),
      );
      await database.markVerseRead(planId, 63, 1, 1);
      await database.insertLog(
        RsLog(
          sessionId: oldSession.id!,
          bookId: 63,
          chapter: 1,
          verse: 1,
          dateTime: yesterday.add(const Duration(hours: 9)),
          readingPlanId: planId,
        ),
      );

      final newSessionId = (await sessionService.rolloverSession(
        oldSession.id!,
        at: now,
        oldReadSeconds: 300,
        newReadSeconds: 0,
      ))!;

      expect(newSessionId, isNot(oldSession.id));
      final newRuntime = await runtimeFor(newSessionId);
      expect(newRuntime.versesToday, 0);
      expect(newRuntime.secondsToday, 0);

      final unchecked = (await setVerseRead(
        newSessionId,
        _readOptions(63, 1, 1, read: false),
      ))!;
      final uncheckedStates = await statesFor(newSessionId, 63, 1);
      expect(uncheckedStates[1]?.readCount, 1);
      expect(uncheckedStates[1]?.readThisSession, isFalse);
      expect((await runtimeFor(newSessionId)).versesToday, 0);
      expect(unchecked.bookCompleted, isNull);
      expect(
        await database.getRsLogForSessionAndVerse(oldSession.id!, 63, 1, 1),
        hasLength(1),
      );

      await setVerseRead(newSessionId, _readOptions(63, 1, 1, read: true));
      final checkedStates = await statesFor(newSessionId, 63, 1);
      expect(checkedStates[1]?.readCount, 2);
      expect(checkedStates[1]?.readThisSession, isTrue);
      expect((await runtimeFor(newSessionId)).versesToday, 1);
      expect(
        await database.getRsLogForSessionAndVerse(oldSession.id!, 63, 1, 1),
        hasLength(1),
      );
      expect(
        await database.getRsLogForSessionAndVerse(newSessionId, 63, 1, 1),
        hasLength(1),
      );
    },
  );

  test(
    'session operations reject stale sessions until an explicit rollover',
    () async {
      final planId = await planService.saveReadingPlan(
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

      final rolledId = (await sessionService.rolloverSession(
        oldSession.id!,
        at: now,
        oldReadSeconds: 300,
        newReadSeconds: 0,
      ))!;

      expect(rolledId, isNot(oldSession.id));
      final old = (await database.getSessionById(oldSession.id!))!;
      expect(old.readSeconds, 300);
      expect(old.endTime, yesterday.add(const Duration(days: 1, seconds: -1)));

      expect(await sessionService.heartbeat(rolledId, readSeconds: 0), isTrue);
      expect((await runtimeFor(rolledId)).sessionId, rolledId);
    },
  );

  test('reports book completion with the next resume position', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Completion Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 15,
      selectedBookIds: {63, 64},
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

  test('heartbeat extends the session and end closes it', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Heartbeat Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {63},
    );

    final sessionId = await startPlan(planId);
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(await sessionService.heartbeat(sessionId, readSeconds: 1), isTrue);
    expect((await runtimeFor(sessionId)).secondsToday, greaterThanOrEqualTo(1));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final beforeActivity = await database.readModels.getDayActivity(
      planId,
      today,
    );
    final beforeEnd = beforeActivity.single.rsSession.endTime;
    expect(beforeEnd, isNotNull);

    await sessionService.endSession(sessionId, readSeconds: 0);

    final activity = await database.readModels.getDayActivity(planId, today);
    final sessions = [for (final session in activity) session.rsSession];
    expect(sessions, hasLength(1));
    expect(sessions.single.endTime, isNotNull);

    final summary = (await database.readModels.getPlanSummary(
      planId,
      today: today,
    ))!.today;
    expect(summary.hasSummary, isTrue);
    expect(summary.seconds, greaterThanOrEqualTo(1));
  });

  test('returns null for actions on a missing session', () async {
    final planId = await planService.saveReadingPlan(
      planName: 'Missing Session Test',
      collectionId: 1,
      goalType: GoalType.verses,
      goalValue: 10,
      selectedBookIds: {63},
    );

    final sessionId = await startPlan(planId);
    await sessionService.endSession(sessionId, readSeconds: 0);

    expect(await sessionService.heartbeat(-1, readSeconds: 0), isFalse);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: true)), isNull);
    expect(await setVerseRead(-1, _readOptions(63, 1, 1, read: false)), isNull);
    expect(await statesFor(-1, 63, 1), isEmpty);
  });
}
