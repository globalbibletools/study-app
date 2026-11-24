import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart' show GoalType;
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

  Future<int> createPlan(String name, {List<int> bookIds = const [63]}) {
    return database.readingPlans.commit(
      ReadingPlan(
        id: 0,
        planName: name,
        createdAt: DateTime(2026, 11, 20),
        goalType: GoalType.verses,
        goalValue: 10,
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

    planId = await createPlan('Session Repository Test');
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

  test('commit inserts a new session and returns it with an id', () async {
    final session = sessionFor(
      planId,
      DateTime(2026, 11, 20),
      readSeconds: 90,
      verses: 3,
    );

    final saved = await database.session.commit(session);

    expect(saved.id, isNotNull);
    expect(saved.rsDate, session.rsDate);
    expect(saved.startTime, session.startTime);
    expect(saved.endTime, session.endTime);
    expect(saved.readSeconds, 90);
    expect(saved.verses, 3);
    expect(saved.readingPlanId, planId);

    final fetched = await database.session.getById(saved.id!);
    expect(fetched, isNotNull);
    expect(fetched!.id, saved.id);
  });

  test('commit updates an existing session', () async {
    final saved = await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20)),
    );

    final endTime = DateTime(2026, 11, 20, 10, 30);
    final updated = saved.copyWith(
      endTime: endTime,
      readSeconds: 600,
      verses: 5,
    );

    final committed = await database.session.commit(updated);
    expect(committed.id, saved.id);

    final fetched = (await database.session.getById(saved.id!))!;
    expect(fetched.id, saved.id);
    expect(fetched.endTime, endTime);
    expect(fetched.readSeconds, 600);
    expect(fetched.verses, 5);
  });

  test('getById returns null for a missing session', () async {
    expect(await database.session.getById(999), isNull);
  });

  test('getById returns the matching session', () async {
    final saved = await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), readSeconds: 120, verses: 2),
    );

    final fetched = await database.session.getById(saved.id!);

    expect(fetched, isNotNull);
    expect(fetched!.id, saved.id);
    expect(fetched.rsDate, DateTime(2026, 11, 20));
    expect(fetched.readSeconds, 120);
    expect(fetched.verses, 2);
    expect(fetched.readingPlanId, planId);
  });

  test('delete removes only the session it identifies', () async {
    final first = await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), hour: 8),
    );
    final second = await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), hour: 9),
    );

    expect(await database.session.delete(first.id!), 1);

    expect(await database.session.getById(first.id!), isNull);
    expect(await database.session.getById(second.id!), isNotNull);
  });

  test('delete returns zero for an unknown id', () async {
    expect(await database.session.delete(999), 0);
  });

  test('deleteForPlanId deletes only the sessions for that plan', () async {
    final otherPlanId = await createPlan('Other Plan', bookIds: [64]);
    await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), hour: 8),
    );
    await database.session.commit(sessionFor(planId, DateTime(2026, 11, 21)));
    await database.session.commit(
      sessionFor(otherPlanId, DateTime(2026, 11, 20)),
    );

    expect(await database.session.deleteForPlanId(planId), 2);

    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), planId),
      0,
    );
    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), otherPlanId),
      1,
    );
  });

  test('deleteForPlanId honors a transaction executor', () async {
    await database.session.commit(sessionFor(planId, DateTime(2026, 11, 20)));

    await expectLater(
      database.transaction((txn) async {
        await database.session.deleteForPlanId(planId, executor: txn);
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), planId),
      1,
    );

    await database.transaction((txn) async {
      await database.session.deleteForPlanId(planId, executor: txn);
    });

    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), planId),
      0,
    );
  });

  test('countForDate counts sessions for the plan on the given date', () async {
    final otherPlanId = await createPlan('Other Plan', bookIds: [64]);

    await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), hour: 8),
    );
    await database.session.commit(
      sessionFor(planId, DateTime(2026, 11, 20), hour: 9),
    );
    // Different date, same plan.
    await database.session.commit(sessionFor(planId, DateTime(2026, 11, 21)));
    // Same date, different plan.
    await database.session.commit(
      sessionFor(otherPlanId, DateTime(2026, 11, 20)),
    );

    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), planId),
      2,
    );
    expect(
      await database.session.countForDate(DateTime(2026, 11, 21), planId),
      1,
    );
    expect(
      await database.session.countForDate(DateTime(2026, 11, 20), otherPlanId),
      1,
    );
    expect(
      await database.session.countForDate(DateTime(2026, 11, 22), planId),
      0,
    );
  });
}
