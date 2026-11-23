import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_collection.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/edit_reading_plan_view_model.dart';
import 'package:gbt/reading_plan/goal_value_editor.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/bible_navigation_fixture.dart';
import 'fake_reading_plan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingPlanService planService;
  late BibleNavigation bibleNavigation;

  setUp(() {
    planService = FakeReadingPlanService();
    bibleNavigation = createTestBibleNavigation();
  });

  EditReadingPlanViewModel newViewModel([String name = 'Plan']) {
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

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Material(color: Theme.of(context).colorScheme.surface, child: child),
      home: home,
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester,
    EditReadingPlanViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: EditReadingPlanPanel.withDependencies(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(
    WidgetTester tester,
    EditReadingPlanViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      buildApp(
        _EditorLauncher(
          onOpen: (context) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  EditReadingPlanPanel.withDependencies(viewModel: viewModel),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('goal controls fit on one line and switch goal type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPanel(tester, newViewModel());

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
      of: find.byType(GoalValueEditor),
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
    expect(
      find.textContaining(RegExp(r'\(\w{3} \d{1,2}, \d{4}\)')),
      findsOneWidget,
    );
    expect(find.textContaining('months'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing the name updates the view model', (tester) async {
    final viewModel = newViewModel();
    await pumpPanel(tester, viewModel);

    await tester.enterText(find.byType(TextFormField), 'Morning Reading');
    await tester.pump();

    expect(viewModel.name, 'Morning Reading');
  });

  testWidgets(
    'saving a new plan closes the editor and shows submitting state',
    (tester) async {
      planService.queueSaveRequests = true;
      final viewModel = newViewModel('New Plan');
      await openPanel(tester, viewModel);

      await tester.enterText(find.byType(TextFormField), 'Saved Plan');
      await tester.tap(find.text('Save Reading Plan'));
      await tester.pump();

      expect(planService.saveRequests, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(submitButton.onPressed, isNull);

      planService.saveRequests.single.complete();
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);
      expect(planService.saveCalls.single.planName, 'Saved Plan');
    },
  );

  testWidgets(
    'updating an existing plan closes the editor and shows submitting state',
    (tester) async {
      planService.queueSaveRequests = true;
      final details = existingPlan(name: 'Original');
      final viewModel = existingViewModel(details);
      await openPanel(tester, viewModel);

      expect(find.text('Update Reading Plan'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Updated');
      await tester.tap(find.text('Update Reading Plan'));
      await tester.pump();

      expect(planService.saveRequests, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(submitButton.onPressed, isNull);
      expect(planService.saveCalls.single.existingPlanDetails, same(details));

      planService.saveRequests.single.complete();
      await tester.pumpAndSettle();

      expect(find.byType(EditReadingPlanPanel), findsNothing);
      expect(find.text('Open editor'), findsOneWidget);
      expect(planService.saveCalls.single.planName, 'Updated');
    },
  );

  testWidgets('delete asks for confirmation before removing the plan', (
    tester,
  ) async {
    final details = existingPlan(id: 2, name: 'Doomed');
    planService.plans = [details];
    final viewModel = existingViewModel(details);
    await openPanel(tester, viewModel);

    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete Reading Plan?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(planService.deletedPlanIds, isEmpty);
    expect(find.byType(EditReadingPlanPanel), findsOneWidget);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(planService.deletedPlanIds, [2]);
    expect(planService.plans, isEmpty);
    expect(find.byType(EditReadingPlanPanel), findsNothing);
    expect(find.text('Open editor'), findsOneWidget);
  });

  testWidgets('changing the collection updates the selected books', (
    tester,
  ) async {
    final viewModel = newViewModel();
    await pumpPanel(tester, viewModel);

    await tester.tap(find.byType(DropdownButton<BibleCollection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Testament').last);
    await tester.pumpAndSettle();

    expect(viewModel.selectedCollection.id, 3);
    expect(viewModel.selectedBookIds, {for (int i = 40; i <= 66; i++) i});
    expect(find.text('New Testament'), findsOneWidget);
  });

  testWidgets('selecting Custom shows it with an empty selection', (
    tester,
  ) async {
    final viewModel = newViewModel();
    await pumpPanel(tester, viewModel);

    await tester.tap(find.byType(DropdownButton<BibleCollection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(viewModel.selectedCollection, same(BibleCollections.custom));
    expect(viewModel.orderedBookIds, isEmpty);
    expect(viewModel.collectionBookCount, 0);
    expect(find.text('Custom'), findsOneWidget);

    final submitButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submitButton.onPressed, isNull);
  });

  testWidgets('custom book list survives switching to a preset and back', (
    tester,
  ) async {
    final viewModel = newViewModel();
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
    expect(viewModel.selectedCollection.id, 3);
    expect(find.text('New Testament'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<BibleCollection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    expect(viewModel.selectedCollection, same(BibleCollections.custom));
    expect(viewModel.orderedBookIds, [2, 1]);
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('saves a custom collection from the editor', (tester) async {
    final viewModel = newViewModel('Custom Plan');
    await openPanel(tester, viewModel);

    await tester.tap(find.byType(DropdownButton<BibleCollection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();

    viewModel.setBooks([8, 2, 1]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Reading Plan'));
    await tester.pumpAndSettle();

    expect(find.byType(EditReadingPlanPanel), findsNothing);
    expect(planService.saveCalls.single.collectionId, 0);
    expect(planService.saveCalls.single.orderedBookIds, [8, 2, 1]);
    expect(planService.plans.single.readingPlan.collectionId, 0);
    expect(planService.plans.single.books.map((b) => b.bookId), [8, 2, 1]);
  });

  testWidgets('disables save when the name is empty', (tester) async {
    final viewModel = newViewModel();
    await pumpPanel(tester, viewModel);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.pump();

    final submitButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(submitButton.onPressed, isNull);
  });

  group('navigation helpers', () {
    setUp(() {
      getIt.registerSingleton<ReadingPlanService>(planService);
      getIt.registerSingleton<BibleNavigation>(bibleNavigation);
    });

    tearDown(() async {
      await getIt.reset();
    });

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

    testWidgets(
      'navigateToExisting opens an initialized existing plan editor',
      (tester) async {
        final details = existingPlan(id: 4, name: 'Existing Plan');

        await tester.pumpWidget(
          buildApp(
            _EditorLauncher(
              onOpen: (context) =>
                  EditReadingPlanPanel.navigateToExisting(context, details),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();

        expect(find.byType(EditReadingPlanPanel), findsOneWidget);
        expect(find.text('Edit Reading Plan'), findsOneWidget);
        expect(find.text('Existing Plan'), findsOneWidget);
        expect(find.text('Whole Bible'), findsOneWidget);
      },
    );
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

ReadingPlanDetails existingPlan({int id = 1, String name = 'Existing Plan'}) {
  final details = EditReadingPlanViewModel.defaultPlan(name);
  return ReadingPlanDetails(
    details.readingPlan.copyWith(id: id),
    details.books,
  );
}
