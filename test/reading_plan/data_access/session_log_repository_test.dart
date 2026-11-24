import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart'
    as repo;
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart' show GoalType;
import 'package:gbt/reading_plan/data_access/session_log_repository.dart';
import 'package:gbt/reading_plan/data_access/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late int planId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<int> createPlan(String name) {
    return database.readingPlans.commit(
      repo.ReadingPlan(
        id: 0,
        planName: name,
        createdAt: DateTime(2026, 11, 20),
        goalType: GoalType.verses,
        goalValue: 10,
        isBookmarked: false,
        bookIds: [63],
      ),
    );
  }

  setUp(() async {
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();

    planId = await createPlan('Session Log Repository Test');
  });

  tearDown(() {
    database.dispose();
  });

  Future<Session> insertSession(
    int readingPlanId,
    DateTime day, {
    int hour = 9,
  }) {
    final startTime = DateTime(day.year, day.month, day.day, hour);
    return database.session.commit(
      Session(
        rsDate: DateTime(day.year, day.month, day.day),
        startTime: startTime,
        endTime: startTime,
        verses: 0,
        readingPlanId: readingPlanId,
      ),
    );
  }

  SessionLogEntry entryFor(
    int sessionId,
    int verse, {
    DateTime? dateTime,
    int? readingPlanId,
  }) {
    return SessionLogEntry(
      sessionId: sessionId,
      readingPlanId: readingPlanId ?? planId,
      bookId: 63,
      chapter: 1,
      verse: verse,
      dateTime: dateTime ?? DateTime(2026, 11, 20, 9, verse),
    );
  }

  test('appends a read log and returns its id', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final entry = entryFor(session.id!, 1);

    final savedId = await database.sessionLog.append(entry);

    final logs = await database.sessionLog.listForSession(session.id!);
    expect(logs, hasLength(1));
    expect(logs.single.id, savedId);
    expect(logs.single.sessionId, session.id);
    expect(logs.single.readingPlanId, planId);
    expect(logs.single.bookId, 63);
    expect(logs.single.chapter, 1);
    expect(logs.single.verse, 1);
    expect(logs.single.dateTime, entry.dateTime);
  });

  test('append honors a transaction executor', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));

    await database.transaction((txn) async {
      await database.sessionLog.append(entryFor(session.id!, 1), executor: txn);
    });

    expect(await database.sessionLog.listForSession(session.id!), hasLength(1));

    await expectLater(
      database.transaction((txn) async {
        await database.sessionLog.append(
          entryFor(session.id!, 2),
          executor: txn,
        );
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    final logs = await database.sessionLog.listForSession(session.id!);
    expect(logs, hasLength(1));
    expect(logs.single.verse, 1);
  });

  test('getVerseLogForSession returns the matching log', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final otherSession = await insertSession(planId, DateTime(2026, 11, 20));
    final savedId = await database.sessionLog.append(entryFor(session.id!, 1));
    await database.sessionLog.append(entryFor(session.id!, 2));
    await database.sessionLog.append(entryFor(otherSession.id!, 1));

    final log = await database.sessionLog.getVerseLogForSession(
      session.id!,
      63,
      1,
      1,
    );

    expect(log, isNotNull);
    expect(log!.id, savedId);
    expect(log.sessionId, session.id);
    expect(log.readingPlanId, planId);
    expect(log.bookId, 63);
    expect(log.chapter, 1);
    expect(log.verse, 1);

    expect(
      await database.sessionLog.getVerseLogForSession(session.id!, 63, 1, 3),
      isNull,
    );
  });

  test('getVerseLogForSession honors a transaction executor', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final savedId = await database.sessionLog.append(entryFor(session.id!, 1));

    await database.transaction((txn) async {
      final log = await database.sessionLog.getVerseLogForSession(
        session.id!,
        63,
        1,
        1,
        executor: txn,
      );

      expect(log?.id, savedId);
    });
  });

  test('remove deletes only the entry it identifies', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final otherSession = await insertSession(planId, DateTime(2026, 11, 20));
    final firstId = await database.sessionLog.append(entryFor(session.id!, 1));
    await database.sessionLog.append(entryFor(session.id!, 2));
    await database.sessionLog.append(entryFor(otherSession.id!, 1));

    expect(await database.sessionLog.remove(firstId), 1);

    final remaining = await database.sessionLog.listForSession(session.id!);
    expect(remaining.map((log) => log.verse), [2]);

    final otherSessionLogs = await database.sessionLog.listForSession(
      otherSession.id!,
    );
    expect(otherSessionLogs.map((log) => log.verse), [1]);
  });

  test('remove returns zero for an unknown id', () async {
    expect(await database.sessionLog.remove(999), 0);
  });

  test('remove honors a transaction executor', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final savedId = await database.sessionLog.append(entryFor(session.id!, 1));

    await expectLater(
      database.transaction((txn) async {
        await database.sessionLog.remove(savedId, executor: txn);
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    expect(await database.sessionLog.listForSession(session.id!), hasLength(1));

    await database.transaction((txn) async {
      await database.sessionLog.remove(savedId, executor: txn);
    });

    expect(await database.sessionLog.listForSession(session.id!), isEmpty);
  });

  test('deleteForPlanId deletes only the entries for that plan', () async {
    final otherPlanId = await createPlan('Other Plan');
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    final otherSession = await insertSession(
      otherPlanId,
      DateTime(2026, 11, 20),
    );
    await database.sessionLog.append(entryFor(session.id!, 1));
    await database.sessionLog.append(entryFor(session.id!, 2));
    await database.sessionLog.append(
      entryFor(otherSession.id!, 1, readingPlanId: otherPlanId),
    );

    expect(await database.sessionLog.deleteForPlanId(planId), 2);

    expect(await database.sessionLog.listForSession(session.id!), isEmpty);
    final otherLogs = await database.sessionLog.listForSession(
      otherSession.id!,
    );
    expect(otherLogs, hasLength(1));
    expect(otherLogs.single.readingPlanId, otherPlanId);
  });

  test('deleteForPlanId honors a transaction executor', () async {
    final session = await insertSession(planId, DateTime(2026, 11, 20));
    await database.sessionLog.append(entryFor(session.id!, 1));

    await expectLater(
      database.transaction((txn) async {
        await database.sessionLog.deleteForPlanId(planId, executor: txn);
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    expect(await database.sessionLog.listForSession(session.id!), hasLength(1));

    await database.transaction((txn) async {
      await database.sessionLog.deleteForPlanId(planId, executor: txn);
    });

    expect(await database.sessionLog.listForSession(session.id!), isEmpty);
  });
}
