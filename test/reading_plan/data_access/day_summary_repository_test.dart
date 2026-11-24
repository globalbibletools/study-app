import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
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

  Future<int> createPlan(
    String name, {
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    List<int> bookIds = const [63],
  }) {
    return database.readingPlans.commit(
      ReadingPlan(
        id: 0,
        planName: name,
        createdAt: DateTime(2026, 11, 20),
        goalType: goalType,
        goalValue: goalValue,
        isBookmarked: false,
        bookIds: bookIds,
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

    planId = await createPlan('Day Summary Repository Test');
  });

  tearDown(() {
    database.dispose();
  });

  Session sessionFor(
    int readingPlanId,
    DateTime day, {
    int hour = 9,
    int readSeconds = 0,
    int verses = 0,
  }) {
    final startTime = DateTime(day.year, day.month, day.day, hour);
    return Session(
      rsDate: DateTime(day.year, day.month, day.day),
      startTime: startTime,
      endTime: startTime,
      readSeconds: readSeconds,
      verses: verses,
      readingPlanId: readingPlanId,
    );
  }

  test('upsert sums totals across every session for the day', () async {
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 3));
    await database.session.commit(
      sessionFor(planId, day, hour: 10, readSeconds: 120, verses: 2),
    );
    // A session on another day must not leak into the day's totals.
    await database.session.commit(sessionFor(planId, DateTime(2026, 11, 21)));

    await database.daySummary.upsert(planId, day);

    final summary = (await database.daySummary.get(planId, day))!;
    expect(summary.rsSeconds, 120);
    expect(summary.rsVerses, 5);
    expect(summary.rsDate, day);

    expect(
      await database.daySummary.get(planId, DateTime(2026, 11, 21)),
      isNull,
    );
  });

  test('upsert marks a verses goal reached from summed verses', () async {
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 4));
    await database.session.commit(sessionFor(planId, day, hour: 10, verses: 6));

    await database.daySummary.upsert(planId, day);

    final summary = (await database.daySummary.get(planId, day))!;
    expect(summary.goalReached, isTrue);
    expect(summary.goalType, GoalType.verses);
    expect(summary.goalValue, 10);
  });

  test('upsert marks a minutes goal reached from summed seconds', () async {
    final minutesPlanId = await createPlan(
      'Minutes Plan',
      goalType: GoalType.minutes,
      goalValue: 5,
    );
    final day = DateTime(2026, 11, 20);
    await database.session.commit(
      sessionFor(minutesPlanId, day, readSeconds: 150),
    );
    await database.session.commit(
      sessionFor(minutesPlanId, day, hour: 10, readSeconds: 150, verses: 2),
    );

    await database.daySummary.upsert(minutesPlanId, day);

    final summary = (await database.daySummary.get(minutesPlanId, day))!;
    expect(summary.goalReached, isTrue);
    expect(summary.goalType, GoalType.minutes);
    expect(summary.goalValue, 5);

    // The verses goal on the first plan is not reached by seconds alone.
    await database.session.commit(sessionFor(planId, day, readSeconds: 600));
    await database.daySummary.upsert(planId, day);
    expect((await database.daySummary.get(planId, day))!.goalReached, isFalse);
  });

  test('upsert replaces an existing row', () async {
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 2));
    await database.daySummary.upsert(planId, day);
    expect((await database.daySummary.get(planId, day))!.rsVerses, 2);

    await database.session.commit(
      sessionFor(planId, day, hour: 10, readSeconds: 60, verses: 1),
    );
    await database.daySummary.upsert(planId, day);

    final summary = (await database.daySummary.get(planId, day))!;
    expect(summary.rsVerses, 3);
    expect(summary.rsSeconds, 60);
  });

  test('preserveStoredGoalSnapshot keeps the stored snapshot after the plan '
      'goal changes', () async {
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 7));
    await database.daySummary.upsert(planId, day);

    // The plan's goal later changes to minutes.
    await database.session.commit(
      sessionFor(planId, day, hour: 11, readSeconds: 300),
    );
    final savedPlan = (await database.readingPlans.getById(planId))!;
    await database.readingPlans.commit(
      savedPlan.copyWith(goalType: GoalType.minutes, goalValue: 5),
    );

    await database.daySummary.upsert(
      planId,
      day,
      preserveStoredGoalSnapshot: true,
    );

    final summary = (await database.daySummary.get(planId, day))!;
    expect(summary.goalType, GoalType.verses);
    expect(summary.goalValue, 10);
    expect(summary.goalReached, isFalse);

    // Without the flag the snapshot follows the plan's current goal.
    await database.daySummary.upsert(planId, day);
    final refreshed = (await database.daySummary.get(planId, day))!;
    expect(refreshed.goalType, GoalType.minutes);
    expect(refreshed.goalValue, 5);
    expect(refreshed.goalReached, isTrue);
  });

  test('preserveStoredGoalSnapshot falls back to the plan goal when no '
      'stored snapshot exists', () async {
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 12));

    await database.daySummary.upsert(
      planId,
      day,
      preserveStoredGoalSnapshot: true,
    );

    final summary = (await database.daySummary.get(planId, day))!;
    expect(summary.goalType, GoalType.verses);
    expect(summary.goalValue, 10);
    expect(summary.goalReached, isTrue);
  });

  test('delete removes only the row it identifies', () async {
    final firstDay = DateTime(2026, 11, 20);
    final secondDay = DateTime(2026, 11, 21);
    await database.session.commit(sessionFor(planId, firstDay, verses: 1));
    await database.session.commit(sessionFor(planId, secondDay, verses: 1));
    await database.daySummary.upsert(planId, firstDay);
    await database.daySummary.upsert(planId, secondDay);

    expect(await database.daySummary.deleteForDay(planId, firstDay), 1);

    expect(await database.daySummary.get(planId, firstDay), isNull);
    expect(await database.daySummary.get(planId, secondDay), isNotNull);
  });

  test('delete returns zero when no row exists', () async {
    expect(
      await database.daySummary.deleteForDay(planId, DateTime(2026, 11, 20)),
      0,
    );
  });

  test('deleteForPlanId removes only the target plan rows', () async {
    final otherPlanId = await createPlan('Other Plan', bookIds: [64]);
    final day = DateTime(2026, 11, 20);
    await database.session.commit(sessionFor(planId, day, verses: 1));
    await database.session.commit(sessionFor(otherPlanId, day, verses: 1));
    await database.daySummary.upsert(planId, day);
    await database.daySummary.upsert(otherPlanId, day);

    expect(await database.daySummary.deleteForPlanId(planId), 1);

    expect(await database.daySummary.get(planId, day), isNull);
    expect(await database.daySummary.get(otherPlanId, day), isNotNull);
  });

  test(
    'upsert with an executor participates in the caller transaction',
    () async {
      final day = DateTime(2026, 11, 20);
      await database.session.commit(sessionFor(planId, day, verses: 4));

      await database.transaction((txn) async {
        await database.daySummary.upsert(planId, day, executor: txn);

        final rows = await txn.query(
          'rs_day_summary',
          where: 'reading_plan_id = ?',
          whereArgs: [planId],
        );
        expect(rows, hasLength(1));
        expect(rows.first['rs_verses'], 4);
      });

      expect(await database.daySummary.get(planId, day), isNotNull);
    },
  );

  test(
    'delete with an executor participates in the caller transaction',
    () async {
      final day = DateTime(2026, 11, 20);
      await database.session.commit(sessionFor(planId, day, verses: 4));
      await database.daySummary.upsert(planId, day);

      // A failing transaction rolls the delete back.
      await expectLater(
        database.transaction((txn) async {
          await database.daySummary.deleteForDay(planId, day, executor: txn);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await database.daySummary.get(planId, day), isNotNull);

      // A successful transaction commits it.
      await database.transaction((txn) async {
        await database.daySummary.deleteForDay(planId, day, executor: txn);
      });
      expect(await database.daySummary.get(planId, day), isNull);
    },
  );
}
