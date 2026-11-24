import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/cancellation.dart';
import 'package:gbt/reading_plan/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';

import '../../fixtures/bible_navigation_fixture.dart';
import '../fake_reading_plan_service.dart';

void main() {
  late FakeReadingPlanService planService;
  late BibleNavigation bibleNavigation;

  setUp(() {
    planService = FakeReadingPlanService();
    bibleNavigation = createTestBibleNavigation();
  });

  Future<EditReadingPlanViewModel> newViewModel([String name = 'Test Plan']) {
    return EditReadingPlanViewModel.createNew(
      name,
      planService: planService,
      bibleNavigation: bibleNavigation,
    );
  }

  Future<EditReadingPlanViewModel> existingViewModel(
    ReadingPlanDetails details,
  ) {
    planService.plans = [details];
    return EditReadingPlanViewModel.createExisting(
      details.readingPlan.id!,
      planService: planService,
      bibleNavigation: bibleNavigation,
    );
  }

  Future<ReadingPlanDetails> savePlan({
    String name = 'Saved Plan',
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    List<int> bookIds = const [1, 2],
  }) async {
    final planId = await planService.saveReadingPlan(
      planName: name,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
    );
    return (await planService.getReadingPlanById(planId))!;
  }

  group('defaultPlan', () {
    test(
      'creates an unsaved whole-Bible plan with a 10-verse daily goal',
      () async {
        final details = EditReadingPlanViewModel.defaultPlan('Morning Reading');

        final plan = details.readingPlan;
        expect(plan.id, isNull);
        expect(plan.planName, 'Morning Reading');
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
      },
    );
  });

  group('initialization', () {
    test('seeds a new-plan view model with whole-Bible defaults', () async {
      final vm = await newViewModel('My Plan');

      expect(vm.isExisting, isFalse);
      expect(vm.name, 'My Plan');
      expect(vm.selectedCollection, BibleCollection.wholeBible);
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
        goalType: GoalType.minutes,
        goalValue: 20,
        bookIds: [45, 46],
      );

      final vm = await existingViewModel(details);

      expect(vm.isExisting, isTrue);
      expect(vm.name, 'Epistles');
      expect(vm.selectedCollection, BibleCollection.custom);
      expect(vm.selectedBookIds, {45, 46});
      expect(vm.goalType, GoalType.minutes);
      expect(vm.goalValue, 20);
      expect(vm.selectedBookCount, 2);
      expect(vm.canSubmit, isTrue);
    });

    test('always offers Custom as a collection option', () async {
      final vm = await newViewModel();
      expect(vm.collectionOptions.last, same(BibleCollection.custom));

      vm.setBooks([2, 1]);

      expect(vm.collectionOptions.last, same(BibleCollection.custom));
    });

    test('initializes the custom draft from an existing custom plan', () async {
      final planId = await planService.saveReadingPlan(
        planName: 'Custom Plan',
        goalType: GoalType.verses,
        goalValue: 10,
        bookIds: [46, 45],
      );
      final details = (await planService.getReadingPlanById(planId))!;

      final vm = await existingViewModel(details);
      expect(vm.selectedCollection, same(BibleCollection.custom));
      expect(vm.orderedBookIds, [46, 45]);

      vm.selectCollection(BibleCollection.newTestament); // New Testament
      vm.selectCollection(BibleCollection.custom);

      expect(vm.selectedCollection, same(BibleCollection.custom));
      expect(vm.orderedBookIds, [46, 45]);
    });
  });

  group('setters', () {
    test('setPlanName updates the name and notifies once per change', () async {
      final vm = await newViewModel('My Plan');
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
      () async {
        final vm = await newViewModel();
        var notifications = 0;
        vm.addListener(() => notifications++);

        vm.selectCollection(BibleCollection.newTestament); // New Testament

        expect(notifications, 1);
        expect(vm.selectedCollection, BibleCollection.newTestament);
        expect(vm.selectedBookIds, {for (int i = 40; i <= 66; i++) i});
        expect(vm.selectedBookCount, 27);
        expect(vm.collectionBookCount, 27);

        vm.selectCollection(BibleCollection.newTestament);
        expect(notifications, 1);
      },
    );

    test('selectCollection discards a partial book selection', () async {
      final vm = await newViewModel();
      vm.setBooks([1, 5]);

      vm.selectCollection(BibleCollection.torah); // Torah

      expect(vm.selectedBookIds, {1, 2, 3, 4, 5});
    });

    test(
      'selectCollection selects Custom with no books when no draft exists',
      () async {
        final vm = await newViewModel();
        var notifications = 0;
        vm.addListener(() => notifications++);

        vm.selectCollection(BibleCollection.custom);

        expect(vm.selectedCollection, same(BibleCollection.custom));
        expect(vm.orderedBookIds, isEmpty);
        expect(vm.collectionBookCount, 0);
        expect(vm.selectedBookCount, 0);
        expect(vm.canSubmit, isFalse);
        expect(notifications, 1);
      },
    );

    test('setGoalType updates the goal type and notifies on change', () async {
      final vm = await newViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setGoalType(GoalType.minutes);

      expect(notifications, 1);
      expect(vm.goalType, GoalType.minutes);

      vm.setGoalType(GoalType.minutes);
      expect(notifications, 1);
    });

    test('setGoalValue rejects non-positive values', () async {
      final vm = await newViewModel();
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setGoalValue(0);
      vm.setGoalValue(-3);

      expect(notifications, 0);
      expect(vm.goalValue, 10);
    });

    test('setGoalValue updates positive values and notifies once', () async {
      final vm = await newViewModel();
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
    test('a preset order keeps its collection selected', () async {
      final vm = await newViewModel();

      vm.setBooks(BibleCollection.gospels.books);

      expect(vm.selectedCollection, BibleCollection.gospels);
      expect(vm.orderedBookIds, [40, 41, 42, 43]);
    });

    test('a reordered preset selects Custom', () async {
      final vm = await newViewModel();
      final reversed = BibleCollection.torah.books.reversed.toList();

      vm.setBooks(reversed);

      expect(vm.selectedCollection, same(BibleCollection.custom));
      expect(vm.orderedBookIds, reversed);
    });

    test('a non-preset order selects Custom', () async {
      final vm = await newViewModel();
      final notifications = <int>[];
      vm.addListener(() => notifications.add(1));

      vm.setBooks([2, 1]);

      expect(vm.selectedCollection, BibleCollection.custom);
      expect(vm.orderedBookIds, [2, 1]);
      expect(notifications, hasLength(1));
    });

    test('an identical order is ignored', () async {
      final vm = await newViewModel();
      vm.setBooks([2, 1]);
      var notifications = 0;
      vm.addListener(() => notifications++);

      vm.setBooks([2, 1]);

      expect(notifications, 0);
    });
  });

  group('custom draft', () {
    test('retains a custom draft across preset switches', () async {
      final vm = await newViewModel();
      vm.selectCollection(BibleCollection.custom);
      vm.setBooks([8, 2, 1]);

      vm.selectCollection(BibleCollection.gospels); // Gospels
      expect(vm.selectedCollection, BibleCollection.gospels);

      vm.selectCollection(BibleCollection.torah); // Torah
      expect(vm.selectedCollection, BibleCollection.torah);

      vm.selectCollection(BibleCollection.custom);

      expect(vm.selectedCollection, same(BibleCollection.custom));
      expect(vm.orderedBookIds, [8, 2, 1]);
    });

    test(
      'editing to a preset order leaves the custom draft unchanged',
      () async {
        final vm = await newViewModel();
        vm.selectCollection(BibleCollection.custom);
        vm.setBooks([2, 1]);

        vm.setBooks(BibleCollection.gospels.books);
        expect(vm.selectedCollection, BibleCollection.gospels);

        vm.selectCollection(BibleCollection.custom);

        expect(vm.orderedBookIds, [2, 1]);
      },
    );
  });

  group('estimatedDays', () {
    // Ruth (book 8) has 85 verses in the versification fixture.
    Future<EditReadingPlanViewModel> ruthViewModel() async {
      final vm = await newViewModel();
      vm.setBooks([8]);
      return vm;
    }

    test(
      'divides total verses by a verses-per-day goal, rounding up',
      () async {
        final vm = await ruthViewModel();

        expect(vm.estimatedDays, 9); // ceil(85 / 10)
      },
    );

    test('counts only selected books', () async {
      final vm = await ruthViewModel();

      vm.setBooks([8, 32]); // Ruth + Jonah (48 verses)

      expect(vm.estimatedDays, 14); // ceil(133 / 10)
    });

    test('converts verses to minutes at five verses per minute', () async {
      final vm = await ruthViewModel();
      vm.setGoalType(GoalType.minutes);
      vm.setGoalValue(5);

      // ceil(ceil(85 / 5) / 5) = ceil(17 / 5) = 4
      expect(vm.estimatedDays, 4);
    });

    test('clamps an empty selection to one day', () async {
      final vm = await newViewModel();
      vm.setBooks([]);

      expect(vm.estimatedDays, 1);
    });

    test('clamps large goals to a minimum of one day', () async {
      final vm = await ruthViewModel();
      vm.setGoalValue(1000);

      expect(vm.estimatedDays, 1);
    });

    test('books missing from the versification contribute no verses', () async {
      final vm = await newViewModel();
      vm.setBooks([999]);

      expect(vm.estimatedDays, 1);
    });

    test('estimatedCompletionDate is estimatedDays from now', () async {
      final vm = await ruthViewModel();
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
      final vm = await newViewModel('Daily Bread');
      vm.selectCollection(BibleCollection.gospels); // Gospels
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
      expect(call.planId, isNull);
      expect(call.planName, 'Daily Bread');
      expect(call.goalType, GoalType.verses);
      expect(call.goalValue, 25);
      expect(call.bookIds, [40, 41, 42, 43]);

      final saved = planService.plans.single;
      expect(saved.readingPlan.id, isNotNull);
      expect(saved.books.map((b) => b.bookId), [40, 41, 42, 43]);
      expect(saved.books.map((b) => b.ord), [1, 2, 3, 4]);
    });

    test('saves a whole-Bible plan in canonical order', () async {
      final vm = await newViewModel('Through the Bible');

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.bookIds, [for (int i = 1; i <= 66; i++) i]);
    });

    test('saves the custom order', () async {
      final vm = await newViewModel('Custom Plan');
      vm.selectCollection(BibleCollection.custom);
      vm.setBooks([3, 1, 2]);

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.bookIds, [3, 1, 2]);

      final saved = planService.plans.single;
      expect(saved.books.map((b) => b.bookId), [3, 1, 2]);
    });

    test('does not persist an unselected custom draft', () async {
      final vm = await newViewModel('Torah Plan');
      vm.selectCollection(BibleCollection.custom);
      vm.setBooks([2, 1]);
      vm.selectCollection(BibleCollection.torah); // Torah

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.single;
      expect(call.bookIds, [1, 2, 3, 4, 5]);

      final reopened = await existingViewModel(planService.plans.single);
      expect(reopened.selectedCollection, BibleCollection.torah);

      reopened.selectCollection(BibleCollection.custom);
      expect(reopened.orderedBookIds, isEmpty);
    });

    test('passes the existing plan through when updating', () async {
      final saved = await savePlan(name: 'Original', bookIds: [2, 1]);
      final originalId = saved.readingPlan.id;

      final vm = await existingViewModel(saved);
      vm.setPlanName('Revised');
      vm.setBooks([1, 3]); // drop Exodus (2), add Leviticus (3)

      expect(await vm.submit(), isTrue);

      final call = planService.saveCalls.last;
      expect(call.planId, saved.readingPlan.id);
      expect(call.planName, 'Revised');
      expect(call.bookIds, [1, 3]);

      final updated = planService.plans.single;
      expect(updated.readingPlan.id, originalId);
      expect(updated.readingPlan.planName, 'Revised');
      expect(updated.books.map((b) => b.bookId), [1, 3]);
      expect(updated.books.map((b) => b.ord), [1, 2]);
    });

    test('does not save when the name is empty', () async {
      final vm = await newViewModel('');

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(planService.saveCalls, isEmpty);
    });

    test('does not save when no books are selected', () async {
      final vm = await newViewModel('Some Plan');
      vm.setBooks([]);

      expect(await vm.submit(), isFalse);
      expect(vm.isSubmitting, isFalse);
      expect(planService.saveCalls, isEmpty);
    });

    test('saves the name without trimming it', () async {
      final vm = await newViewModel('  Padded  ');
      expect(vm.canSubmit, isTrue);

      expect(await vm.submit(), isTrue);

      expect(planService.saveCalls.single.planName, '  Padded  ');
    });

    test('propagates save errors and resets the submitting state', () async {
      final vm = await newViewModel('Plan');
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
      final vm = await newViewModel('Plan');

      final first = vm.submit();
      final second = await vm.submit();

      expect(second, isFalse);
      expect(planService.saveCalls, hasLength(1));

      planService.saveRequests.single.complete();
      expect(await first, isTrue);
    });

    test('does not notify after dispose while a save is in flight', () async {
      planService.queueSaveRequests = true;
      final vm = await newViewModel('Plan');
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
      final vm = await newViewModel();

      await vm.delete();

      expect(planService.deletedPlanIds, isEmpty);
    });

    test('propagates delete errors', () async {
      final details = await savePlan(name: 'Doomed', bookIds: [1]);
      final vm = await existingViewModel(details);
      planService.deleteError = StateError('delete failed');

      await expectLater(vm.delete(), throwsA(isA<StateError>()));

      expect(planService.deletedPlanIds, isEmpty);
    });

    test('cancels an in-flight delete when disposed', () async {
      planService.queueDeleteRequests = true;
      final details = await savePlan(name: 'Doomed', bookIds: [1]);
      final vm = await existingViewModel(details);

      final future = vm.delete();
      expect(planService.deleteRequests, hasLength(1));

      vm.dispose();
      planService.deleteRequests.single.complete();
      await expectLater(future, throwsA(isA<CancelledError>()));
    });
  });
}
