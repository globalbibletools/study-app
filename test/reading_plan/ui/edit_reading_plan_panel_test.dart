import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/asyncutils/serial_queue.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:gbt/reading_plan/bible_collection.dart';
import 'package:gbt/reading_plan/data_access/rs_database.dart';
import 'package:gbt/reading_plan/model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/ui/edit_book_list_panel.dart';
import 'package:gbt/reading_plan/ui/edit_book_list_view_model.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/ui/number_stepper.dart';
import 'package:gbt/ui/messaging/messenger_host.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/fake_messenger_view_model.dart';
import '../fixtures/reading_plan_test_stack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReadingPlanTestStack stack;
  late ReadingSessionDatabase database;
  late ReadingPlanService planService;
  late FakeMessengerViewModel messenger;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    stack = await ReadingPlanTestStack.create();
    database = stack.database;
    planService = stack.planService;
    messenger = stack.messenger;
  });

  tearDown(() => stack.dispose());

  Future<int> createPlan({
    String name = 'Existing Plan',
    GoalType goalType = GoalType.verses,
    int goalValue = 10,
    List<int> bookIds = const [1, 2],
  }) {
    return planService.saveReadingPlan(
      planName: name,
      goalType: goalType,
      goalValue: goalValue,
      bookIds: bookIds,
    );
  }

  Future<EditReadingPlanViewModel> newViewModel([String name = 'Plan']) {
    return EditReadingPlanViewModel.createNew(name);
  }

  Future<EditReadingPlanViewModel> existingViewModel(int planId) {
    return EditReadingPlanViewModel.createExisting(planId);
  }

  Future<EditReadingPlanViewModel> newDirectViewModel([
    String name = 'Plan',
  ]) async {
    final viewModel = await newViewModel(name);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Future<EditReadingPlanViewModel> existingDirectViewModel(int planId) async {
    final viewModel = await existingViewModel(planId);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: MessengerHost(
          messenger: messenger,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: home,
    );
  }

  Future<void> waitFor(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 300; attempt++) {
      if (condition()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('Timed out waiting for the widget to update.');
  }

  Future<EditReadingPlanViewModel> pumpPanel(
    WidgetTester tester,
    EditReadingPlanViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      buildApp(Scaffold(body: EditReadingPlanPanel(viewModel: viewModel))),
    );
    await tester.pumpAndSettle();
    return viewModel;
  }

  Future<EditReadingPlanViewModel> openPanel(
    WidgetTester tester,
    EditReadingPlanViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      buildApp(
        _EditorLauncher(
          onOpen: (context) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => EditReadingPlanPanel(viewModel: viewModel),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return viewModel;
  }

  Future<EditBookListViewModel> openBookEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('edit-book-list')));
    await waitFor(
      tester,
      () => find.byType(EditBookListPanel).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    return tester
        .widget<EditBookListPanel>(find.byType(EditBookListPanel))
        .viewModel;
  }

  Future<void> removeBook(WidgetTester tester, int bookId) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(bookId)),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
  }

  Future<void> dragBook(
    WidgetTester tester,
    int fromBookId,
    int toBookId,
  ) async {
    final handle = find.descendant(
      of: find.byKey(ValueKey(fromBookId)),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final distance =
        tester.getCenter(find.byKey(ValueKey(toBookId))).dy -
        tester.getCenter(find.byKey(ValueKey(fromBookId))).dy;

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(Offset(0, distance * 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<List<int>> savedBookIds(String planName) async {
    final plans = await database.readingPlans.list();
    return plans.singleWhere((plan) => plan.planName == planName).bookIds;
  }

  group('editor', () {
    testWidgets('renders name, collection, goal controls, and estimate', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel('My Plan')))!;

      await pumpPanel(tester, viewModel);

      expect(find.text('Create Reading Plan'), findsOneWidget);
      expect(find.text('My Plan'), findsOneWidget);
      expect(find.text('Whole Bible'), findsOneWidget);
      expect(find.text('verses'), findsOneWidget);
      expect(find.text('per day'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\(\w{3} \d{1,2}, \d{4}\)')),
        findsOneWidget,
      );
      expect(find.text('Save Reading Plan'), findsOneWidget);
    });

    testWidgets('goal controls fit on one line and switch goal type', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      final nameInput = find.byType(TextFormField);
      final booksDropdown = find.byType(DropdownButton<BibleCollection>);
      expect(
        tester.getSize(nameInput).height,
        tester.getSize(booksDropdown).height,
      );
      expect(
        tester.getTopLeft(find.text('Plan')).dx,
        tester.getTopLeft(find.text('Whole Bible')).dx,
      );
      expect(
        tester.getCenter(find.text('Whole Bible')).dy,
        closeTo(tester.getCenter(booksDropdown).dy, 0.1),
      );

      final valueField = find.descendant(
        of: find.byType(NumberStepper),
        matching: find.byType(TextField),
      );

      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('verses'), findsOneWidget);
      expect(find.text('per day'), findsOneWidget);
      expect(tester.widget<TextField>(valueField).controller!.text, '10');

      final dropdown = find.byKey(const Key('goal-type-dropdown'));
      final versesDropdownWidth = tester.getSize(dropdown).width;
      expect(
        tester.getSize(dropdown).height,
        tester.getSize(find.byKey(const Key('goal-increase'))).height + 2,
      );
      expect(
        tester.getCenter(find.text('verses')).dy,
        closeTo(tester.getCenter(find.byIcon(Icons.add)).dy, 1),
      );
      expect(
        tester.getCenter(find.text('per day')).dy,
        closeTo(tester.getCenter(find.byIcon(Icons.add)).dy, 1),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(tester.widget<TextField>(valueField).controller!.text, '11');

      await tester.tap(find.text('verses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('minutes').last);
      await tester.pumpAndSettle();

      expect(find.text('minutes'), findsOneWidget);
      expect(find.text('verses'), findsNothing);
      expect(find.text('per day'), findsOneWidget);
      expect(tester.getSize(dropdown).width, greaterThan(versesDropdownWidth));
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing the name updates the view model', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await tester.enterText(find.byType(TextFormField), 'Morning Reading');
      await tester.pump();

      expect(viewModel.name, 'Morning Reading');
    });

    testWidgets('disables save when the name is empty', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump();

      final submitButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(submitButton.onPressed, isNull);
    });

    test('rejects non-positive goal values', () async {
      final viewModel = await newDirectViewModel();

      viewModel.setGoalValue(0);
      viewModel.setGoalValue(-3);

      expect(viewModel.goalValue, 10);
    });

    testWidgets('loads an existing plan into the editor', (tester) async {
      final planId = (await tester.runAsync(
        () => createPlan(
          name: 'Epistles',
          goalType: GoalType.minutes,
          goalValue: 20,
          bookIds: const [45, 46],
        ),
      ))!;
      final viewModel = (await tester.runAsync(
        () => existingViewModel(planId),
      ))!;

      await pumpPanel(tester, viewModel);

      expect(find.text('Edit Reading Plan'), findsOneWidget);
      expect(find.text('Epistles'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('minutes'), findsOneWidget);
      expect(find.text('Update Reading Plan'), findsOneWidget);
    });

    test('createExisting throws when the plan is missing', () async {
      await expectLater(existingViewModel(999999), throwsA(isA<StateError>()));
    });
  });

  group('collections', () {
    testWidgets('changing the collection updates the selected books', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Testament').last);
      await tester.pumpAndSettle();

      expect(viewModel.selectedCollection, BibleCollection.newTestament);
      expect(viewModel.selectedBookIds, {for (int i = 40; i <= 66; i++) i});
      expect(find.text('New Testament'), findsOneWidget);
    });

    testWidgets('selecting Custom shows it with an empty selection', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      expect(viewModel.selectedCollection, same(BibleCollection.custom));
      expect(viewModel.orderedBookIds, isEmpty);
      expect(viewModel.collectionBookCount, 0);
      expect(find.text('Custom'), findsOneWidget);

      final submitButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('custom book list survives switching to a preset and back', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      viewModel.setBooks([2, 1]);
      await tester.pumpAndSettle();
      expect(find.text('Custom'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Testament').last);
      await tester.pumpAndSettle();
      expect(viewModel.selectedCollection, BibleCollection.newTestament);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      expect(viewModel.selectedCollection, same(BibleCollection.custom));
      expect(viewModel.orderedBookIds, [2, 1]);
    });

    testWidgets('saves a custom collection order to the database', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(
        () => newViewModel('Custom Plan'),
      ))!;
      await openPanel(tester, viewModel);

      await tester.tap(find.byType(DropdownButton<BibleCollection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();

      viewModel.setBooks([8, 2, 1]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Reading Plan'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isEmpty,
      );

      expect(await tester.runAsync(() => savedBookIds('Custom Plan')), [
        8,
        2,
        1,
      ]);
    });

    test('does not persist an unselected custom draft', () async {
      final viewModel = await newDirectViewModel('Torah Plan');
      viewModel.selectCollection(BibleCollection.custom);
      viewModel.setBooks([2, 1]);
      viewModel.selectCollection(BibleCollection.torah);

      expect(await viewModel.submit(), isTrue);

      expect(await savedBookIds('Torah Plan'), [1, 2, 3, 4, 5]);
    });
  });

  group('save', () {
    testWidgets('saves a new plan and closes the editor', (tester) async {
      final viewModel = (await tester.runAsync(
        () => newViewModel('New Plan'),
      ))!;
      viewModel.setBooks([1, 2]);
      await openPanel(tester, viewModel);

      await tester.enterText(find.byType(TextFormField), 'Saved Plan');
      await tester.tap(find.text('Save Reading Plan'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isEmpty,
      );

      expect(find.text('Open editor'), findsOneWidget);
      expect(await tester.runAsync(() => savedBookIds('Saved Plan')), [1, 2]);
    });

    testWidgets('updates an existing plan and closes the editor', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(name: 'Original', bookIds: const [2, 1]),
      ))!;
      final viewModel = (await tester.runAsync(
        () => existingViewModel(planId),
      ))!;
      await openPanel(tester, viewModel);

      await tester.enterText(find.byType(TextFormField), 'Updated');
      viewModel.setBooks([1, 3, 2]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Reading Plan'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isEmpty,
      );

      final saved = await tester.runAsync(
        () => database.readingPlans.getById(planId),
      );
      expect(saved!.planName, 'Updated');
      expect(saved.bookIds, [1, 3, 2]);
    });

    test('a submit while one is in flight is ignored', () async {
      final viewModel = await newDirectViewModel('Daily Bread');
      viewModel.setBooks([1, 2]);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final first = viewModel.submit();
      final duplicate = viewModel.submit();

      expect(await first, isTrue);
      expect(await duplicate, isFalse);
      expect(notifications, 0);

      final plans = await database.readingPlans.list();
      expect(
        plans.where((plan) => plan.planName == 'Daily Bread'),
        hasLength(1),
      );
      expect(await savedBookIds('Daily Bread'), [1, 2]);
    });

    test('rechecks validity when the queued command runs', () async {
      final viewModel = await newDirectViewModel('Plan');
      viewModel.setBooks([1]);

      // Occupy the queue, then invalidate the plan before submit runs.
      final delete = viewModel.delete();
      final submit = viewModel.submit();
      viewModel.setPlanName('');

      await delete;

      expect(await submit, isFalse);
      final plans = await database.readingPlans.list();
      expect(plans.where((plan) => plan.planName == 'Plan'), isEmpty);
    });

    test('does not save with an empty name or no books', () async {
      final noName = await newDirectViewModel('');
      final noBooks = await newDirectViewModel('No Books');
      noBooks.setBooks([]);

      expect(await noName.submit(), isFalse);
      expect(await noBooks.submit(), isFalse);

      expect(
        (await database.readingPlans.list()).any(
          (plan) => plan.planName == 'No Books',
        ),
        isFalse,
      );
    });

    test('saves the name without trimming it', () async {
      final viewModel = await newDirectViewModel('  Padded  ');
      viewModel.setBooks([1]);

      expect(await viewModel.submit(), isTrue);

      final plans = await database.readingPlans.list();
      expect(plans.any((plan) => plan.planName == '  Padded  '), isTrue);
    });

    test('propagates save errors', () async {
      final viewModel = await newDirectViewModel('Plan');
      viewModel.setBooks([1]);
      stack.disposeDatabase();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(viewModel.submit(), throwsA(isA<Object>()));

      expect(viewModel.canSubmit, isTrue);
    });

    test('finishes an in-flight save when disposed', () async {
      final viewModel = await EditReadingPlanViewModel.createNew('Plan');
      viewModel.setBooks([1]);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final future = viewModel.submit();
      viewModel.dispose();

      expect(await future, isTrue);
      expect(notifications, 0);
    });
  });

  group('delete', () {
    testWidgets('confirms before deleting and removes the plan', (
      tester,
    ) async {
      final planId = (await tester.runAsync(() => createPlan(name: 'Doomed')))!;
      final viewModel = (await tester.runAsync(
        () => existingViewModel(planId),
      ))!;
      await openPanel(tester, viewModel);

      final deleteButton = find.byIcon(Icons.delete_outline_rounded);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('Delete Reading Plan?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => database.readingPlans.getById(planId)),
        isNotNull,
      );
      expect(find.byType(EditReadingPlanPanel), findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isEmpty,
      );

      expect(
        await tester.runAsync(() => database.readingPlans.getById(planId)),
        isNull,
      );
      expect(find.text('Open editor'), findsOneWidget);
    });

    test('is a no-op for an unsaved plan', () async {
      final viewModel = await newDirectViewModel();
      final before = (await database.readingPlans.list()).length;

      await viewModel.delete();

      expect((await database.readingPlans.list()).length, before);
    });

    test('propagates delete errors', () async {
      final planId = await createPlan(name: 'Doomed');
      final viewModel = await existingDirectViewModel(planId);
      stack.disposeDatabase();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await expectLater(viewModel.delete(), throwsA(isA<Object>()));
    });

    test(
      'a repeated delete joins the in-flight one instead of failing',
      () async {
        final planId = await createPlan(name: 'Doomed');
        final viewModel = await existingDirectViewModel(planId);

        final first = viewModel.delete();
        final second = viewModel.delete();
        expect(identical(first, second), isTrue);

        await Future.wait([first, second]);

        expect(await database.readingPlans.getById(planId), isNull);
      },
    );

    test(
      'dispose finishes in-flight work and drops pending commands',
      () async {
        final planId = await createPlan(name: 'Doomed');
        final viewModel = await EditReadingPlanViewModel.createExisting(planId);

        final current = viewModel.submit();
        final pending = viewModel.delete();
        final pendingExpectation = expectLater(
          pending,
          throwsA(isA<SerialQueueClosed>()),
        );

        viewModel.dispose();

        expect(await current, isTrue);
        await pendingExpectation;
        expect(await database.readingPlans.getById(planId), isNotNull);
      },
    );
  });

  group('book sorting', () {
    testWidgets('reorders books, saves the list, and persists the plan order', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(
        () => newViewModel('Sorted Plan'),
      ))!;
      viewModel.setBooks([1, 2, 3]);
      await openPanel(tester, viewModel);

      await openBookEditor(tester);
      expect(find.text('Customize Books'), findsOneWidget);

      await dragBook(tester, 1, 2);
      await tester.tap(find.text('Save'));
      await waitFor(
        tester,
        () => find.byType(EditBookListPanel).evaluate().isEmpty,
      );

      expect(viewModel.orderedBookIds, [2, 1, 3]);

      await tester.tap(find.text('Save Reading Plan'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isEmpty,
      );

      expect(await tester.runAsync(() => savedBookIds('Sorted Plan')), [
        2,
        1,
        3,
      ]);
    });

    testWidgets('adds a book and saves the new order', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      viewModel.setBooks([1, 2, 3]);
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Numbers').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await waitFor(
        tester,
        () => find.byType(EditBookListPanel).evaluate().isEmpty,
      );

      expect(viewModel.orderedBookIds, [1, 2, 3, 4]);
    });

    testWidgets('removes a book and saves the order', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      viewModel.setBooks([1, 2, 3]);
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);
      await removeBook(tester, 2);
      await tester.tap(find.text('Save'));
      await waitFor(
        tester,
        () => find.byType(EditBookListPanel).evaluate().isEmpty,
      );

      expect(viewModel.orderedBookIds, [1, 3]);
    });

    testWidgets('clears books and disables saving', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      viewModel.setBooks([1, 2]);
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);
      await tester.tap(find.byKey(const Key('clear-books')));
      await tester.pump();
      expect(find.text('Select at least one book'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await waitFor(
        tester,
        () => find.byType(EditBookListPanel).evaluate().isEmpty,
      );

      expect(viewModel.orderedBookIds, isEmpty);
      final submitButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(submitButton.onPressed, isNull);
    });

    testWidgets('shows the all-books-selected state', (tester) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);

      expect(find.text('All books selected'), findsOneWidget);
      expect(find.text('Add book'), findsNothing);
    });

    testWidgets('back without changes keeps the original order', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      viewModel.setBooks([2, 1]);
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(EditBookListPanel),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditBookListPanel), findsNothing);
      expect(viewModel.orderedBookIds, [2, 1]);
    });

    testWidgets('back with changes can keep editing or discard', (
      tester,
    ) async {
      final viewModel = (await tester.runAsync(() => newViewModel()))!;
      viewModel.setBooks([1, 2]);
      await pumpPanel(tester, viewModel);

      await openBookEditor(tester);
      await removeBook(tester, 1);

      final backButton = find.descendant(
        of: find.byType(EditBookListPanel),
        matching: find.byIcon(Icons.arrow_back),
      );
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(EditBookListPanel), findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();

      expect(find.byType(EditBookListPanel), findsNothing);
      expect(viewModel.orderedBookIds, [1, 2]);
    });

    test('ignores invalid book operations', () {
      final viewModel = EditBookListViewModel([1, 2, 3]);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.addBook(2);
      viewModel.addBook(999);
      viewModel.removeBook(4);
      viewModel.moveBook(-1, 0);
      viewModel.moveBook(0, -1);
      viewModel.moveBook(3, 0);
      viewModel.moveBook(0, 3);
      viewModel.moveBook(1, 1);

      expect(viewModel.bookIds, [1, 2, 3]);
      expect(notifications, 0);
    });

    test('starts with a defensive copy and updates availability', () {
      final initial = [3, 1, 2];
      final viewModel = EditBookListViewModel(initial);

      initial.add(4);

      expect(viewModel.bookIds, [3, 1, 2]);
      expect(viewModel.availableBookIds.contains(3), isFalse);
      expect(viewModel.availableBookIds.contains(4), isTrue);

      viewModel.removeBook(1);

      expect(viewModel.bookIds, [3, 2]);
      expect(viewModel.availableBookIds.contains(1), isTrue);
    });

    test('clearing an empty list is a no-op', () {
      final viewModel = EditBookListViewModel(const []);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.clearBooks();

      expect(viewModel.bookIds, isEmpty);
      expect(notifications, 0);
    });

    test('tracks and reverts changes', () {
      final viewModel = EditBookListViewModel([1, 2, 3]);
      expect(viewModel.hasChanges, isFalse);

      viewModel.addBook(4);
      expect(viewModel.hasChanges, isTrue);
      viewModel.removeBook(4);
      expect(viewModel.hasChanges, isFalse);

      viewModel.moveBook(0, 1);
      expect(viewModel.hasChanges, isTrue);
      viewModel.moveBook(1, 0);
      expect(viewModel.hasChanges, isFalse);

      viewModel.clearBooks();
      expect(viewModel.hasChanges, isTrue);
      viewModel.addBook(1);
      viewModel.addBook(2);
      viewModel.addBook(3);
      expect(viewModel.hasChanges, isFalse);
    });
  });

  group('estimated completion', () {
    // Ruth (book 8) has 85 verses in the versification fixture.
    Future<EditReadingPlanViewModel> ruthViewModel() async {
      final viewModel = await newDirectViewModel();
      viewModel.setBooks([8]);
      return viewModel;
    }

    test('estimates days from selected books for a verse goal', () async {
      final viewModel = await ruthViewModel();

      expect(viewModel.estimatedDays, 9);

      viewModel.setBooks([8, 32]);
      expect(viewModel.estimatedDays, 14);
    });

    test('converts minutes to verses for a minutes goal', () async {
      final viewModel = await ruthViewModel();
      viewModel.setGoalType(GoalType.minutes);
      viewModel.setGoalValue(5);

      expect(viewModel.estimatedDays, 4);
    });

    test('clamps estimates for empty, huge, and missing books', () async {
      final empty = await newDirectViewModel();
      empty.setBooks([]);
      expect(empty.estimatedDays, 1);

      final huge = await ruthViewModel();
      huge.setGoalValue(1000);
      expect(huge.estimatedDays, 1);

      final missing = await newDirectViewModel();
      missing.setBooks([999]);
      expect(missing.estimatedDays, 1);
    });

    test('estimatedCompletionDate is estimatedDays from now', () async {
      final viewModel = await ruthViewModel();
      final now = DateTime.now();

      final completion = viewModel.estimatedCompletionDate;

      expect(
        completion.difference(now).inSeconds,
        closeTo(const Duration(days: 9).inSeconds, 1),
      );
    });
  });

  group('navigation helpers', () {
    testWidgets('navigateToNew opens an initialized new plan editor', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          _EditorLauncher(
            onOpen: (context) =>
                EditReadingPlanPanel.navigateToNew(context, 'New Plan'),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsOneWidget);
      expect(find.text('Create Reading Plan'), findsOneWidget);
      expect(find.text('New Plan'), findsOneWidget);
      expect(find.text('Whole Bible'), findsOneWidget);
    });

    testWidgets('navigateToExisting opens an initialized existing editor', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(name: 'Existing Plan'),
      ))!;

      await tester.pumpWidget(
        buildApp(
          _EditorLauncher(
            onOpen: (context) =>
                EditReadingPlanPanel.navigateToExisting(context, planId),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await waitFor(
        tester,
        () => find.byType(EditReadingPlanPanel).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsOneWidget);
      expect(find.text('Edit Reading Plan'), findsOneWidget);
      expect(find.text('Existing Plan'), findsOneWidget);
    });

    testWidgets('navigateToExisting shows an error when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          _EditorLauncher(
            onOpen: (context) =>
                EditReadingPlanPanel.navigateToExisting(context, 999999),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);

      final l10n = AppLocalizations.of(
        tester.element(find.text('Open editor')),
      )!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);
      expect(messenger.messages.single.text, l10n.errorLoadingContent);

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    testWidgets('navigateToExisting uses the registered messenger', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          _EditorLauncher(
            onOpen: (context) =>
                EditReadingPlanPanel.navigateToExisting(context, 999999),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await waitFor(tester, () => messenger.messages.isNotEmpty);
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsNothing);
      expect(messenger.messages.single.severity.name, 'error');

      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });

    testWidgets('navigateToExisting disposes the view model on unmount', (
      tester,
    ) async {
      final planId = (await tester.runAsync(
        () => createPlan(name: 'Unmounted Plan'),
      ))!;
      late BuildContext staleContext;

      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) {
              staleContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(buildApp(const SizedBox.shrink()));
      await tester.runAsync(
        () => EditReadingPlanPanel.navigateToExisting(staleContext, planId),
      );

      expect(find.byType(EditReadingPlanPanel), findsNothing);
      expect(messenger.messages, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}

class _EditorLauncher extends StatelessWidget {
  const _EditorLauncher({required this.onOpen});

  final Future<void> Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onOpen(context),
          child: const Text('Open editor'),
        ),
      ),
    );
  }
}
