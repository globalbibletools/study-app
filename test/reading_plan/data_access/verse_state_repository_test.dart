import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/model.dart' show GoalType;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;

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
  });

  tearDown(() {
    database.dispose();
  });

  test('markRead increments the count and records last_read', () async {
    final planId = await createPlan('Verse State Repository Test');
    await database.materializeVerseStateForPlan(planId);

    final first = DateTime(2026, 11, 20, 9);
    final second = DateTime(2026, 11, 20, 10);

    await database.verseState.markRead(planId, 63, 1, 1, timestamp: first);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 1);
    expect(
      (await database.verseState.getBookStats(planId))[63]!.lastRead,
      first,
    );

    await database.verseState.markRead(planId, 63, 1, 1, timestamp: second);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 2);
    expect(
      (await database.verseState.getBookStats(planId))[63]!.lastRead,
      second,
    );
  });

  test('unmarkRead decrements and floors at zero', () async {
    final planId = await createPlan('Verse State Repository Test');
    await database.materializeVerseStateForPlan(planId);

    await database.verseState.markRead(planId, 63, 1, 1);

    await database.verseState.unmarkRead(planId, 63, 1, 1);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 0);

    await database.verseState.unmarkRead(planId, 63, 1, 1);
    await database.verseState.unmarkRead(planId, 63, 1, 1);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 0);
  });

  test('unmarkRead nulls last_read when the count reaches zero', () async {
    final planId = await createPlan('Verse State Repository Test');
    await database.materializeVerseStateForPlan(planId);

    await database.verseState.markRead(planId, 63, 1, 1);
    await database.verseState.markRead(planId, 63, 1, 1);

    await database.verseState.unmarkRead(planId, 63, 1, 1);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 1);
    expect(
      (await database.verseState.getBookStats(planId))[63]!.lastRead,
      isNotNull,
    );

    await database.verseState.unmarkRead(planId, 63, 1, 1);
    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 0);
    expect(
      (await database.verseState.getBookStats(planId))[63]!.lastRead,
      isNull,
    );
  });

  test('unmarkRead on a never-read verse leaves the count at zero', () async {
    final planId = await createPlan('Verse State Repository Test');
    await database.materializeVerseStateForPlan(planId);

    await database.verseState.unmarkRead(planId, 63, 1, 2);

    expect(await database.verseState.getReadCount(planId, 63, 1, 2), 0);
    expect(
      (await database.verseState.getBookStats(planId))[63]!.lastRead,
      isNull,
    );
  });

  test('getReadCount returns null for a missing row', () async {
    final planId = await createPlan('Verse State Repository Test');

    expect(await database.verseState.getReadCount(planId, 63, 1, 1), isNull);
  });

  test('isBookComplete needs every verse read', () async {
    final planId = await createPlan('Verse State Repository Test');

    // No rows materialized yet.
    expect(await database.verseState.isBookComplete(planId, 63), isFalse);

    await database.materializeVerseStateForPlan(planId);
    expect(await database.verseState.isBookComplete(planId, 63), isFalse);

    for (var verse = 1; verse <= 12; verse++) {
      await database.verseState.markRead(planId, 63, 1, verse);
    }
    expect(await database.verseState.isBookComplete(planId, 63), isFalse);

    await database.verseState.markRead(planId, 63, 1, 13);
    expect(await database.verseState.isBookComplete(planId, 63), isTrue);
  });

  test('bulkInsert inserts zero-count rows and is idempotent', () async {
    final planId = await createPlan('Verse State Repository Test');
    final inventory = {
      (63, 1): [1, 2, 3],
    };

    await database.verseState.bulkInsert(planId, inventory);

    for (final verse in [1, 2, 3]) {
      expect(await database.verseState.getReadCount(planId, 63, 1, verse), 0);
    }
    expect(await database.verseState.getReadCount(planId, 63, 1, 4), isNull);

    await database.verseState.markRead(planId, 63, 1, 1);
    await database.verseState.bulkInsert(planId, inventory);

    expect(await database.verseState.getReadCount(planId, 63, 1, 1), 1);
    expect(await database.verseState.getReadCount(planId, 63, 1, 4), isNull);
  });

  test('deleteForPlanId deletes only the target plan rows', () async {
    final planId = await createPlan('Verse State Repository Test');
    final otherPlanId = await createPlan(
      'Other Verse State Plan',
      bookIds: [64],
    );
    await database.materializeVerseStateForPlan(planId);
    await database.materializeVerseStateForPlan(otherPlanId);

    expect(await database.verseState.deleteForPlanId(planId), 13);

    expect(await database.verseState.getReadCount(planId, 63, 1, 1), isNull);
    expect(await database.verseState.getReadCount(otherPlanId, 64, 1, 1), 0);
  });

  test(
    'methods with an executor participate in the caller transaction',
    () async {
      final planId = await createPlan('Verse State Repository Test');
      await database.materializeVerseStateForPlan(planId);

      await database.transaction((txn) async {
        await database.verseState.markRead(planId, 63, 1, 1, executor: txn);
        expect(
          await database.verseState.getReadCount(
            planId,
            63,
            1,
            1,
            executor: txn,
          ),
          1,
        );

        await database.verseState.unmarkRead(planId, 63, 1, 1, executor: txn);
        expect(
          await database.verseState.getReadCount(
            planId,
            63,
            1,
            1,
            executor: txn,
          ),
          0,
        );
      });
    },
  );
}
