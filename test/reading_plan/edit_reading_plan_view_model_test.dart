import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

import '../fixtures/bible_navigation_fixture.dart';
import 'fake_reading_plan_service.dart';

void main() {
  late FakeReadingPlanService planService;
  late BibleNavigation bibleNavigation;

  setUp(() {
    planService = FakeReadingPlanService();
    bibleNavigation = createTestBibleNavigation();
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
    final plan = await planService.saveReadingPlan(
      planName: name,
      collectionId: collectionId,
      goalType: goalType,
      goalValue: goalValue,
      selectedBookIds: bookIds,
    );
    return (await planService.getReadingPlanById(plan.id!))!;
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

    test('always offers Custom as a collection option', () {
      final vm = newViewModel();
      expect(vm.collectionOptions.last, same(BibleCollections.custom));

      vm.setBooks([2, 1]);

      expect(vm.collectionOptions.last, same(BibleCollections.custom));
    });

    test('initializes the custom draft from an existing custom plan', () async {
      final plan = await planService.saveReadingPlan(
        planName: 'Custom Plan',
        collectionId: BibleCollections.custom.id,
        goalType: GoalType.verses,
        goalValue: 10,
        selectedBookIds: {46, 45},
        orderedBookIds: [46, 45],
      );
      final details = (await planService.getReadingPlanById(plan.id!))!;

      final vm = existingViewModel(details);
      expect(vm.selectedCollection, same(BibleCollections.custom));
      expect(vm.orderedBookIds, [46, 45]);

      vm.selectCollection(BibleCollections.fromId(3)); // New Testament
      vm.selectCollection(BibleCollections.custom);

      expect(vm.selectedCollection, same(BibleCollections.custom));
      expect(vm.orderedBookIds, [46, 45]);
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
      vm.setBooks([1, 5]);

      vm.selectCollection(BibleCollections.fromId(4)); // Torah

      expect(vm.selectedBookIds, {1, 2, 3, 4, 5});
    });

    test(
      'selectCollection selects Custom with no books when no draft exists',
      () {
        final vm = newViewModel();
        var notifications = 0;
        vm.addListener(() => notifications++);

        vm.selectCollection(BibleCollections.custom);

        expect(vm.selectedCollection, same(BibleCollections.custom));
        expect(vm.orderedBookIds, isEmpty);
        expect(vm.collectionBookCount, 0);
        expect(vm.selectedBookCount, 0);
        expect(vm.canSubmit, isFalse);
        expect(notifications, 1);
      },
    );

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

      vm.setBooks(BibleCollections.fromId(7).books);

      expect(vm.selectedCollection.id, 7);
      expect(vm.orderedBookIds, [40, 41, 42, 43]);
    });

    test('a reordered preset selects Custom', () {
      final vm = newViewModel();
      final reversed = BibleCollections.fromId(4).books.reversed.toList();

      vm.setBooks(reversed);

      expect(vm.selectedCollection, same(BibleCollections.custom));
      expect(vm.orderedBookIds, reversed);
    });

    test('a non-preset order selects Custom', () {
      final vm = newViewModel();
      final notifications = <int>[];
      vm.addListener(() => notifications.add(1));

      vm.setBooks([2, 1]);

      expect(vm.selectedCollection.id, BibleCollections.custom.id);
      expect(vm.orderedBookIds, [2, 1]);
      expect(notifications, hasLength(1));
    });

    test('an identical order is ignored', () {
      final vm = newViewModel();
      vm.setBooks([2, 1]);
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setBooks([2, 1]);

      expect(notifications, 0);
    });
  });

  group('custom draft', () {
    test('retains a custom draft across preset switches', () {
      final vm = newViewModel();
      vm.selectCollection(BibleCollections.custom);
      vm.setBooks([8, 2, 1]);

      vm.selectCollection(BibleCollections.fromId(7)); // Gospels
      expect(vm.selectedCollection.id, 7);

      vm.selectCollection(BibleCollections.fromId(4)); // Torah
      expect(vm.selectedCollection.id, 4);

      vm.selectCollection(BibleCollections.custom);

      expect(vm.selectedCollection, same(BibleCollections.custom));
      expect(vm.orderedBookIds, [8, 2, 1]);
    });

    test('editing to a preset order leaves the custom draft unchanged', () {
      final vm = newViewModel();
      vm.selectCollection(BibleCollections.custom);
      vm.setBooks([2, 1]);

      vm.setBooks(BibleCollections.fromId(7).books);
      expect(vm.selectedCollection.id, 7);

      vm.selectCollection(BibleCollections.custom);

      expect(vm.orderedBookIds, [2, 1]);
    });
  });

  group('estimatedDays', () {
    // Ruth (book 8) has 85 verses in the versification fixture.
    EditReadingPlanViewModel ruthViewModel() {
      final vm = newViewModel();
      vm.setBooks([8]);
      return vm;
    }

    test('divides total verses by a verses-per-day goal, rounding up', () {
      final vm = ruthViewModel();

      expect(vm.estimatedDays, 9); // ceil(85 / 10)
    });

    test('counts only selected books', () {
      final vm = ruthViewModel();

      vm.setBooks([8, 32]); // Ruth + Jonah (48 verses)

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
      vm.setBooks([]);

      expect(vm.estimatedDays, 1);
    });

    test('clamps large goals to a minimum of one day', () {
      final vm = ruthViewModel();
      vm.setGoalValue(1000);

      expect(vm.estimatedDays, 1);
    });

    test('books missing from the versification contribute no verses', () {
      final vm = newViewModel();
      vm.setBooks([999]);

      expect(vm.estimatedDays, 1);
    });

    test('estimatedCompletionDate is estimatedDays from now', () {
      final vm = ruthViewModel();
      final now = DateTime.now();

      final completion = vm.estimatedCompletionDate;

      expect(
        completion.difference(now).inSeconds,
        closeTo(const Duration(days: 9).inSeconds, 1),
      );
    });
  });

  group('submit', () {
    test('saves the current view model state', () async {
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

      final call = planService.saveCalls.single;
      expect(call.existingPlanDetails, isNull);
      expect(call.planName, 'Daily Bread');
      expect(call.collectionId, 7);
      expect(call.goalType, GoalType.verses);
      expect(call.goalValue, 25);
      expect(call.selectedBookIds, {40, 41, 42, 43});
      expect(call.orderedBookIds, [40, 41, 42, 43]);

      final saved = planService.plans.single;
      expect(saved.readingPlan.id, isNotNull);
      expect(saved.books.map((b) => b.bookId), [40, 41, 42, 43]);
      expect(saved.books.map((b) => b.ord), [1, 2, 3, 4]);
    });

    test('saves a whole-Bible plan in canonical order', () async {
      final vm = newViewModel('Through the Bible');

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.orderedBookIds, [for (int i = 1; i <= 66; i++) i]);
    });

    test('saves collectionId 0 with the custom order', () async {
      final vm = newViewModel('Custom Plan');
      vm.selectCollection(BibleCollections.custom);
      vm.setBooks([3, 1, 2]);

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.collectionId, BibleCollections.custom.id);
      expect(call.orderedBookIds, [3, 1, 2]);

      final saved = planService.plans.single;
      expect(saved.readingPlan.collectionId, BibleCollections.custom.id);
      expect(saved.books.map((b) => b.bookId), [3, 1, 2]);
    });

    test('does not persist an unselected custom draft', () async {
      final vm = newViewModel('Torah Plan');
      vm.selectCollection(BibleCollections.custom);
      vm.setBooks([2, 1]);
      vm.selectCollection(BibleCollections.fromId(4)); // Torah

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.collectionId, 4);
      expect(call.orderedBookIds, [1, 2, 3, 4, 5]);

      final reopened = existingViewModel(planService.plans.single);
      expect(reopened.selectedCollection.id, 4);

      reopened.selectCollection(BibleCollections.custom);
      expect(reopened.orderedBookIds, isEmpty);
    });

    test('passes the existing plan through when updating', () async {
      final saved = await savePlan(name: 'Original', bookIds: {2, 1});
      final originalId = saved.readingPlan.id;

      final vm = existingViewModel(saved);
      vm.setPlanName('Revised');
      vm.setBooks([1, 3]); // drop Exodus (2), add Leviticus (3)

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.last;
      expect(call.existingPlanDetails, same(saved));
      expect(call.planName, 'Revised');
      expect(call.orderedBookIds, [1, 3]);

      final updated = planService.plans.single;
      expect(updated.readingPlan.id, originalId);
      expect(updated.readingPlan.planName, 'Revised');
      expect(updated.books.map((b) => b.bookId), [1, 3]);
      expect(updated.books.map((b) => b.ord), [1, 2]);
    });

    test('does not save when the name is empty', () async {
      final vm = newViewModel('');

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(planService.saveCalls, isEmpty);
    });

    test('does not save when no books are selected', () async {
      final vm = newViewModel('Some Plan');
      vm.setBooks([]);

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(planService.saveCalls, isEmpty);
    });

    test('saves the name without trimming it', () async {
      final vm = newViewModel('  Padded  ');
      expect(vm.canSubmit, isTrue);

      expect(await vm.submit(), isTrue);

      expect(planService.saveCalls.single.planName, '  Padded  ');
    });

    test('propagates save errors and resets the submitting state', () async {
      final vm = newViewModel('Plan');
      planService.saveError = StateError('save failed');
      var notifications = 0;
      vm.addListener(() => notifications++);

      await expectLater(vm.submit(), throwsA(isA<StateError>()));

      expect(vm.isSubmitting, isFalse);
      expect(vm.canSubmit, isTrue);
      expect(notifications, 2);
    });

    test('ignores a second submit while the first is saving', () async {
      planService.queueSaveRequests = true;
      final vm = newViewModel('Plan');

      final first = vm.submit();
      final second = await vm.submit();

      expect(second, isFalse);
      expect(planService.saveCalls, hasLength(1));

      planService.saveRequests.single.complete();
      expect(await first, isTrue);
    });

    test('does not notify after dispose while a save is in flight', () async {
      planService.queueSaveRequests = true;
      final vm = newViewModel('Plan');
      var notifications = 0;
      vm.addListener(() => notifications++);

      final future = vm.submit();
      expect(planService.saveRequests, hasLength(1));
      final notificationsBeforeDispose = notifications;

      vm.dispose();
      planService.saveRequests.single.complete();
      await expectLater(future, throwsA(isA<CancelledError>()));

      expect(notifications, notificationsBeforeDispose);
    });
  });

  group('delete', () {
    test('is a no-op for an unsaved plan', () async {
      final vm = newViewModel();

      await vm.delete();

      expect(planService.deletedPlanIds, isEmpty);
    });

    test('propagates delete errors', () async {
      final details = await savePlan(name: 'Doomed', bookIds: {1});
      final vm = existingViewModel(details);
      planService.deleteError = StateError('delete failed');

      await expectLater(vm.delete(), throwsA(isA<StateError>()));

      expect(planService.deletedPlanIds, isEmpty);
    });

    test('cancels an in-flight delete when disposed', () async {
      planService.queueDeleteRequests = true;
      final details = await savePlan(name: 'Doomed', bookIds: {1});
      final vm = existingViewModel(details);

      final future = vm.delete();
      expect(planService.deleteRequests, hasLength(1));

      vm.dispose();
      planService.deleteRequests.single.complete();
      await expectLater(future, throwsA(isA<CancelledError>()));
    });
  });
}
