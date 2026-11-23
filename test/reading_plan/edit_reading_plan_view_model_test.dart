import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/edit_reading_plan_view_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixtures/bible_navigation_fixture.dart';

/// Integration tests for [EditReadingPlanViewModel] running against a real
/// in-memory SQLite database, the real [ReadingPlanService], and a
/// [BibleNavigation] backed by the versification fixture.
///
/// Everything is injected directly; the service locator is never used. Tests
/// that would require modifying injected collaborators (e.g. to manufacture a
/// failing save) are intentionally omitted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late BibleNavigation bibleNavigation;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    bibleNavigation = createTestBibleNavigation();
    database = ReadingSessionDatabase.withDependencies(
      databasePath: inMemoryDatabasePath,
      verseInventoryProvider: (bookIds) async =>
          createTestVerseInventory(bookIds: bookIds),
    );
    await database.init();
    planService = ReadingPlanService.withDependencies(
      database: database,
      bibleNavigation: bibleNavigation,
    );

    // The schema ships with a default "Whole Bible" plan (id 1). Remove it so
    // each test starts from a clean slate.
    for (final plan in await planService.getReadingPlans()) {
      await planService.deleteReadingPlan(plan.readingPlan.id!);
    }
  });

  tearDown(() {
    database.dispose();
  });

  EditReadingPlanViewModel newViewModel([String name = 'Test Plan']) {
    return EditReadingPlanViewModel.withDependencies(
      EditReadingPlanViewModel.defaultPlan(name),
      planService: planService,
      bibleNavigation: bibleNavigation,
    );
  }

  EditReadingPlanViewModel existingViewModel(ReadingPlanDetails details) {
    return EditReadingPlanViewModel.withDependencies(
      details,
      planService: planService,
      bibleNavigation: bibleNavigation,
    );
  }

  Future<ReadingPlanDetails> savePlan({
    String name = 'Saved Plan',
    int collectionId = 1,
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    Set<int> bookIds = const {1, 2},
  }) async {
    final saved = await planService.saveReadingPlan(
      planName: name,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      selectedBookIds: bookIds,
    );
    final details = await planService.getReadingPlanById(saved.id!);
    return details!;
  }

  group('defaultPlan', () {
    test('creates an unsaved whole-Bible plan with a 10-verse daily goal', () {
      final details = EditReadingPlanViewModel.defaultPlan('Morning Reading');

      final plan = details.readingPlan;
      expect(plan.id, isNull);
      expect(plan.planName, 'Morning Reading');
      expect(plan.collectionId, 1);
      expect(plan.goalType, GoalType.verses.name);
      expect(plan.goalValue, 10);

      expect(details.books.map((b) => b.bookId), [
        for (int i = 1; i <= 66; i++) i,
      ]);
      expect(details.books.map((b) => b.ord), [
        for (int i = 1; i <= 66; i++) i,
      ]);
      expect(details.dailyGoal.type, GoalType.verses);
      expect(details.dailyGoal.value, 10);
    });
  });

  group('initialization', () {
    test('seeds a new-plan view model with whole-Bible defaults', () {
      final vm = newViewModel('My Plan');

      expect(vm.isExisting, isFalse);
      expect(vm.name, 'My Plan');
      expect(vm.selectedCollection.id, 1);
      expect(vm.selectedBookIds, {for (int i = 1; i <= 66; i++) i});
      expect(vm.goalType, GoalType.verses);
      expect(vm.goalValue, 10);
      expect(vm.selectedBookCount, 66);
      expect(vm.collectionBookCount, 66);
      expect(vm.canSubmit, isTrue);
      expect(vm.isSubmitting, isFalse);
    });

    test('seeds an existing-plan view model from its saved details', () async {
      final details = await savePlan(
        name: 'Epistles',
        collectionId: 8,
        goalType: GoalType.minutes,
        goalValue: 20,
        bookIds: {45, 46},
      );

      final vm = existingViewModel(details);

      expect(vm.isExisting, isTrue);
      expect(vm.name, 'Epistles');
      expect(vm.selectedCollection.id, BibleCollections.custom.id);
      expect(vm.selectedBookIds, {45, 46});
      expect(vm.goalType, GoalType.minutes);
      expect(vm.goalValue, 20);
      expect(vm.selectedBookCount, 2);
      expect(vm.canSubmit, isTrue);
    });
  });

  group('setters', () {
    test('setPlanName updates the name and notifies once per change', () {
      final vm = newViewModel('My Plan');
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setPlanName('My Plan');
      expect(notifications, 0);

      vm.setPlanName('New Name');
      expect(notifications, 1);
      expect(vm.name, 'New Name');

      vm.setPlanName('New Name');
      expect(notifications, 1);
    });

    test('setPlanName accepts an empty name but blocks submission', () {
      final vm = newViewModel();

      vm.setPlanName('');

      expect(vm.name, '');
      expect(vm.canSubmit, isFalse);
    });

    test(
      'selectCollection switches the collection and resets book selection',
      () {
        final vm = newViewModel();
        var notifications = 0;
        vm.addListener(() => notifications++);

        vm.selectCollection(BibleCollections.fromId(3)); // New Testament

        expect(notifications, 1);
        expect(vm.selectedCollection.id, 3);
        expect(vm.selectedBookIds, {for (int i = 40; i <= 66; i++) i});
        expect(vm.selectedBookCount, 27);
        expect(vm.collectionBookCount, 27);

        vm.selectCollection(BibleCollections.fromId(3));
        expect(notifications, 1);
      },
    );

    test('selectCollection discards a partial book selection', () {
      final vm = newViewModel();
      vm.setSelectedBooks({1, 5});

      vm.selectCollection(BibleCollections.fromId(4)); // Torah

      expect(vm.selectedBookIds, {1, 2, 3, 4, 5});
    });

    test('setSelectedBooks stores a defensive copy of the input', () {
      final vm = newViewModel();
      final selection = <int>{8};
      vm.setSelectedBooks(selection);

      selection.add(9);

      expect(vm.selectedBookIds, {8});
    });

    test('setSelectedBooks ignores identical selections', () {
      final vm = newViewModel();
      vm.setSelectedBooks({8});
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setSelectedBooks({8});

      expect(notifications, 0);
    });

    test('setGoalType updates the goal type and notifies on change', () {
      final vm = newViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setGoalType(GoalType.minutes);

      expect(notifications, 1);
      expect(vm.goalType, GoalType.minutes);

      vm.setGoalType(GoalType.minutes);
      expect(notifications, 1);
    });

    test('setGoalValue rejects non-positive values', () {
      final vm = newViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setGoalValue(0);
      vm.setGoalValue(-3);

      expect(notifications, 0);
      expect(vm.goalValue, 10);
    });

    test('setGoalValue updates positive values and notifies once', () {
      final vm = newViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setGoalValue(25);

      expect(notifications, 1);
      expect(vm.goalValue, 25);

      vm.setGoalValue(25);
      expect(notifications, 1);
    });
  });

  group('book order', () {
    test('a preset order keeps its collection selected', () {
      final vm = newViewModel();

      vm.setBookOrder(BibleCollections.fromId(7).books);

      expect(vm.selectedCollection.id, 7);
      expect(vm.orderedBookIds, [40, 41, 42, 43]);
    });

    test('a non-preset order selects Custom', () {
      final vm = newViewModel();
      final notifications = <int>[];
      vm.addListener(() => notifications.add(1));

      vm.setBookOrder([2, 1]);

      expect(vm.selectedCollection.id, BibleCollections.custom.id);
      expect(vm.orderedBookIds, [2, 1]);
      expect(notifications, hasLength(1));
    });

    test('an identical order is ignored', () {
      final vm = newViewModel();
      vm.setBookOrder([2, 1]);
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setBookOrder([2, 1]);

      expect(notifications, 0);
    });
  });

  group('canSubmit', () {
    test('is false for a whitespace-only name', () {
      final vm = newViewModel();

      vm.setPlanName('   ');

      expect(vm.canSubmit, isFalse);
    });

    test('is false when no books are selected', () {
      final vm = newViewModel();

      vm.setSelectedBooks({});

      expect(vm.selectedBookIds, isEmpty);
      expect(vm.canSubmit, isFalse);
    });
  });

  group('estimatedDays', () {
    // Ruth (book 8) has 85 verses in the versification fixture.
    EditReadingPlanViewModel ruthViewModel() {
      final vm = newViewModel();
      vm.setSelectedBooks({8});
      return vm;
    }

    test('divides total verses by a verses-per-day goal, rounding up', () {
      final vm = ruthViewModel();

      expect(vm.estimatedDays, 9); // ceil(85 / 10)
    });

    test('counts only selected books', () {
      final vm = ruthViewModel();

      vm.setSelectedBooks({8, 32}); // Ruth + Jonah (48 verses)

      expect(vm.estimatedDays, 14); // ceil(133 / 10)
    });

    test('converts verses to minutes at five verses per minute', () {
      final vm = ruthViewModel();
      vm.setGoalType(GoalType.minutes);
      vm.setGoalValue(5);

      // ceil(ceil(85 / 5) / 5) = ceil(17 / 5) = 4
      expect(vm.estimatedDays, 4);
    });

    test('clamps an empty selection to one day', () {
      final vm = newViewModel();
      vm.setSelectedBooks({});

      expect(vm.estimatedDays, 1);
    });

    test('clamps large goals to a minimum of one day', () {
      final vm = ruthViewModel();
      vm.setGoalValue(1000);

      expect(vm.estimatedDays, 1);
    });

    test('books missing from the versification contribute no verses', () {
      final vm = newViewModel();
      vm.setSelectedBooks({999});

      expect(vm.estimatedDays, 1);
    });

    test('estimatedMonths divides estimated days by 30.44', () {
      final vm = ruthViewModel();

      expect(vm.estimatedMonths, closeTo(9 / 30.44, 1e-9));
    });
  });

  group('submit', () {
    test('persists a new plan with the current view model state', () async {
      final vm = newViewModel('Daily Bread');
      vm.selectCollection(BibleCollections.fromId(7)); // Gospels
      vm.setGoalType(GoalType.verses);
      vm.setGoalValue(25);

      var notifications = 0;
      vm.addListener(() => notifications++);

      final future = vm.submit();
      // isSubmitting flips synchronously before the save is awaited.
      expect(vm.isSubmitting, isTrue);
      expect(vm.canSubmit, isFalse);

      expect(await future, isTrue);

      expect(vm.isSubmitting, isFalse);
      expect(vm.canSubmit, isTrue);
      expect(notifications, 2);

      final plans = await planService.getReadingPlans();
      expect(plans, hasLength(1));

      final plan = plans.single.readingPlan;
      expect(plan.id, isNotNull);
      expect(plan.planName, 'Daily Bread');
      expect(plan.collectionId, 7);
      expect(plan.goalType, GoalType.verses.name);
      expect(plan.goalValue, 25);

      expect(plans.single.books.map((b) => b.bookId), [40, 41, 42, 43]);
      expect(plans.single.books.map((b) => b.ord), [1, 2, 3, 4]);

      // Verse state is materialized for the saved books end to end.
      final gospelsVerses = [
        for (final bookId in [40, 41, 42, 43])
          bibleNavigation.getTotalVerseCount(bookId),
      ].reduce((a, b) => a + b);
      final withProgress = await planService.getReadingPlansWithProgress();
      expect(withProgress.single.totalVerses, gospelsVerses);
    });

    test(
      'persists a whole-Bible plan with all books in canonical order',
      () async {
        final vm = newViewModel('Through the Bible');

        expect(await vm.submit(), isTrue);

        final plans = await planService.getReadingPlans();
        expect(plans.single.readingPlan.planName, 'Through the Bible');
        expect(plans.single.books.map((b) => b.bookId), [
          for (int i = 1; i <= 66; i++) i,
        ]);
        expect(plans.single.books.map((b) => b.ord), [
          for (int i = 1; i <= 66; i++) i,
        ]);
      },
    );

    test('persists a custom book order', () async {
      final vm = newViewModel('Custom Order');
      vm.setBookOrder([3, 1]);

      expect(await vm.submit(), isTrue);

      final plans = await planService.getReadingPlans();
      expect(plans.single.readingPlan.collectionId, 0);
      expect(plans.single.books.map((b) => b.bookId), [3, 1]);
      expect(plans.single.books.map((b) => b.ord), [1, 2]);
    });

    test(
      'updates an existing plan in place, preserving prior book order',
      () async {
        final saved = await savePlan(name: 'Original', bookIds: {2, 1});
        final originalId = saved.readingPlan.id;

        final vm = existingViewModel(saved);
        vm.setPlanName('Revised');
        vm.setSelectedBooks({1, 3}); // drop Exodus (2), add Leviticus (3)

        expect(await vm.submit(), isTrue);

        final plans = await planService.getReadingPlans();
        expect(plans, hasLength(1));

        final updated = plans.single;
        expect(updated.readingPlan.id, originalId);
        expect(updated.readingPlan.planName, 'Revised');
        expect(updated.books.map((b) => b.bookId), [1, 3]);
        expect(updated.books.map((b) => b.ord), [1, 2]);
      },
    );

    test('does not persist when the name is empty', () async {
      final vm = newViewModel('');

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(await planService.getReadingPlans(), isEmpty);
    });

    test('does not persist when no books are selected', () async {
      final vm = newViewModel('Some Plan');
      vm.setSelectedBooks({});

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(await planService.getReadingPlans(), isEmpty);
    });

    test('saves the name without trimming it', () async {
      final vm = newViewModel('  Padded  ');
      expect(vm.canSubmit, isTrue);

      expect(await vm.submit(), isTrue);

      final plans = await planService.getReadingPlans();
      expect(plans.single.readingPlan.planName, '  Padded  ');
    });
  });

  group('delete', () {
    test('is a no-op for an unsaved plan', () async {
      final vm = newViewModel();

      await vm.delete();

      expect(await planService.getReadingPlans(), isEmpty);
    });

    test('deletes a saved plan from the database', () async {
      final details = await savePlan(name: 'Doomed', bookIds: {1});
      final vm = existingViewModel(details);

      await vm.delete();

      expect(
        await planService.getReadingPlanById(details.readingPlan.id!),
        isNull,
      );
      expect(await planService.getReadingPlans(), isEmpty);
    });
  });
}
