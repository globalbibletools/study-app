import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_repository.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart' show GoalType;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/bible_navigation_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

  ReadingPlan newPlan({
    String name = 'Repository Test',
    List<int> bookIds = const [3, 1, 2],
  }) {
    return ReadingPlan(
      id: 0,
      planName: name,
      createdAt: DateTime(2026, 1, 1),
      goalType: GoalType.verses,
      goalValue: 10,
      isBookmarked: false,
      bookIds: bookIds,
    );
  }

  group('getById', () {
    test('returns the plan and its ordered book ids as one unit', () async {
      final planId = await database.readingPlans.commit(
        newPlan(name: 'Ordered', bookIds: [63, 1, 19]),
      );

      final plan = await database.readingPlans.getById(planId);

      expect(plan, isNotNull);
      expect(plan!.id, planId);
      expect(plan.planName, 'Ordered');
      expect(plan.goalType, GoalType.verses);
      expect(plan.goalValue, 10);
      expect(plan.isBookmarked, isFalse);
      expect(plan.bookIds, [63, 1, 19]);
    });

    test('returns null for a missing plan id', () async {
      expect(await database.readingPlans.getById(99999), isNull);
    });
  });

  group('commit', () {
    test('creates a plan and its books, returning the new id', () async {
      final before = await database.exportBackupTables();
      final beforePlanIds = before['reading_plan']!
          .map((row) => row['id'] as int)
          .toSet();

      final planId = await database.readingPlans.commit(
        newPlan(bookIds: [1, 2, 3]),
      );

      expect(beforePlanIds.contains(planId), isFalse);

      final persisted = await database.readingPlans.getById(planId);
      expect(persisted, isNotNull);
      expect(persisted!.planName, 'Repository Test');
      expect(persisted.bookIds, [1, 2, 3]);

      final tables = await database.exportBackupTables();
      final bookRows = tables['reading_plan_book']!
          .where((row) => row['reading_plan_id'] == planId)
          .toList();
      expect(bookRows.map((row) => row['book_id']), [1, 2, 3]);
      expect(bookRows.map((row) => row['ord']), [1, 2, 3]);
    });

    test(
      'updates an existing plan, returns its id, and replaces its books',
      () async {
        final planId = await database.readingPlans.commit(
          newPlan(name: 'First', bookIds: [1, 2, 3]),
        );
        final existing = (await database.readingPlans.getById(planId))!;

        final returnedId = await database.readingPlans.commit(
          existing.copyWith(
            planName: 'Renamed',
            goalValue: 20,
            isBookmarked: true,
            bookIds: [5, 4],
          ),
        );

        expect(returnedId, planId);

        final updated = (await database.readingPlans.getById(planId))!;
        expect(updated.planName, 'Renamed');
        expect(updated.goalValue, 20);
        expect(updated.isBookmarked, isTrue);
        // Replacement, not merge: book 1-3 are gone, not appended to.
        expect(updated.bookIds, [5, 4]);
      },
    );

    test('rolls back both tables when a book insert fails', () async {
      final before = await database.exportBackupTables();
      final beforePlanCount = before['reading_plan']!.length;
      final beforeBookCount = before['reading_plan_book']!.length;

      // Duplicate book ids violate the compound primary key mid-transaction.
      await expectLater(
        database.readingPlans.commit(newPlan(name: 'Broken', bookIds: [1, 1])),
        throwsA(isA<DatabaseException>()),
      );

      final after = await database.exportBackupTables();
      expect(after['reading_plan']!.length, beforePlanCount);
      expect(after['reading_plan_book']!.length, beforeBookCount);
      expect(
        after['reading_plan']!.where((row) => row['plan_name'] == 'Broken'),
        isEmpty,
      );
    });

    test(
      'rolls back the plan update when its book replacement fails',
      () async {
        final planId = await database.readingPlans.commit(
          newPlan(name: 'Stable', bookIds: [1]),
        );
        final existing = (await database.readingPlans.getById(planId))!;

        await expectLater(
          database.readingPlans.commit(
            existing.copyWith(planName: 'Mutated', bookIds: [2, 2]),
          ),
          throwsA(isA<DatabaseException>()),
        );

        final after = (await database.readingPlans.getById(planId))!;
        expect(after.planName, 'Stable');
        expect(after.bookIds, [1]);
      },
    );
  });

  group('delete', () {
    test(
      'removes the plan and its books and leaves other plans alone',
      () async {
        final planA = await database.readingPlans.commit(
          newPlan(name: 'Plan A', bookIds: [63, 64]),
        );
        final planB = await database.readingPlans.commit(
          newPlan(name: 'Plan B', bookIds: [1, 2]),
        );

        await database.readingPlans.delete(planA);

        expect(await database.readingPlans.getById(planA), isNull);

        final tables = await database.exportBackupTables();
        expect(
          tables['reading_plan_book']!.where(
            (row) => row['reading_plan_id'] == planA,
          ),
          isEmpty,
        );

        final untouched = await database.readingPlans.getById(planB);
        expect(untouched, isNotNull);
        expect(untouched!.bookIds, [1, 2]);
        expect(
          tables['reading_plan_book']!.where(
            (row) => row['reading_plan_id'] == planB,
          ),
          hasLength(2),
        );
        expect(
          tables['reading_plan']!.where((row) => row['id'] == planB),
          hasLength(1),
        );
      },
    );
  });
}
