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

  setUp(() {
    getIt.registerSingleton<ReadingPlanService>(FakeReadingPlanService());
    getIt.registerSingleton<BibleNavigation>(createTestBibleNavigation());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  testWidgets('goal controls fit on one line and switch goal type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(Scaffold(body: EditReadingPlanPanel.newPlan('Plan'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('BOOKS'), findsOneWidget);
    expect(find.text('COLLECTION'), findsNothing);
    expect(find.text('Create Reading Plan'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    expect(find.text('ESTIMATED COMPLETION'), findsNothing);
    expect(find.byType(Divider), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Save Reading Plan'),
      findsOneWidget,
    );

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

  testWidgets('shows the edit heading for an existing plan', (tester) async {
    final defaultDetails = EditReadingPlanViewModel.defaultPlan('Plan');
    final existingPlan = ReadingPlanDetails(
      defaultDetails.readingPlan.copyWith(id: 1),
      defaultDetails.books,
    );

    await tester.pumpWidget(
      buildApp(Scaffold(body: EditReadingPlanPanel.existing(existingPlan))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Reading Plan'), findsOneWidget);
    expect(find.text('Create Reading Plan'), findsNothing);
  });

  testWidgets('editing the book list updates the collection to Custom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(Scaffold(body: EditReadingPlanPanel.newPlan('Plan'))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-book-list')));
    await tester.pumpAndSettle();

    expect(find.text('Customize Books'), findsOneWidget);

    final genesisRow = find.byKey(const ValueKey(1));
    await tester.tap(
      find.descendant(of: genesisRow, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Customize Books'), findsNothing);
    expect(find.text('Custom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
