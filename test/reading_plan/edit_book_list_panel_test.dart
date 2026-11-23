import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/edit_book_list_panel.dart';
import 'package:gbt/reading_plan/edit_book_list_view_model.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  EditBookListViewModel newViewModel(List<int> bookIds) {
    return EditBookListViewModel(bookIds);
  }

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester,
    EditBookListViewModel viewModel,
  ) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: EditBookListPanel.withDependencies(viewModel: viewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a row for each book in the view model', (tester) async {
    await pumpPanel(tester, newViewModel([2, 1]));

    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(find.text('Genesis'), findsOneWidget);
    expect(find.text('Exodus'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Exodus')).dy,
      lessThan(tester.getTopLeft(find.text('Genesis')).dy),
    );
  });

  testWidgets('shows the empty state when the view model has no books', (
    tester,
  ) async {
    await pumpPanel(tester, newViewModel(const []));

    expect(find.text('Select at least one book'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('shows All books selected when none can be added', (
    tester,
  ) async {
    await pumpPanel(tester, newViewModel([for (int i = 1; i <= 66; i++) i]));

    expect(find.text('All books selected'), findsOneWidget);
    expect(find.text('Add book'), findsNothing);
  });

  testWidgets('removing a book updates the displayed list', (tester) async {
    await pumpPanel(tester, newViewModel(const [1, 2]));

    final genesisRow = find.byKey(const ValueKey(1));
    await tester.tap(
      find.descendant(of: genesisRow, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();

    expect(find.text('Genesis'), findsNothing);
    expect(find.text('Exodus'), findsOneWidget);
  });

  testWidgets('reordering a book updates the displayed order', (tester) async {
    await pumpPanel(tester, newViewModel(const [1, 2, 3]));

    expect(
      tester.getTopLeft(find.text('Genesis')).dy,
      lessThan(tester.getTopLeft(find.text('Exodus')).dy),
    );

    final genesisHandle = find.descendant(
      of: find.byKey(const ValueKey(1)),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final dragDistance =
        tester.getCenter(find.byKey(const ValueKey(2))).dy -
        tester.getCenter(find.byKey(const ValueKey(1))).dy;

    final gesture = await tester.startGesture(tester.getCenter(genesisHandle));
    await tester.pump();
    await gesture.moveBy(Offset(0, dragDistance * 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Exodus')).dy,
      lessThan(tester.getTopLeft(find.text('Genesis')).dy),
    );
  });

  testWidgets('adds a book and scrolls it into view', (tester) async {
    final selectedBookIds = [for (int i = 1; i <= 30; i++) i];
    await pumpPanel(tester, newViewModel(selectedBookIds));

    expect(find.byKey(const ValueKey(31)), findsNothing);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obadiah').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey(31)), findsOneWidget);
    expect(find.text('Obadiah'), findsOneWidget);
  });

  testWidgets('returns the view model book list when Save is tapped', (
    tester,
  ) async {
    final viewModel = newViewModel(const [2, 1]);
    List<int>? result;

    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<List<int>>(
                      MaterialPageRoute(
                        builder: (_) => EditBookListPanel.withDependencies(
                          viewModel: viewModel,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open editor'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, [2, 1]);
  });

  testWidgets(
    'returns the view model book list when the back button is tapped',
    (tester) async {
      final viewModel = newViewModel(const [2, 1]);
      List<int>? result;

      await tester.pumpWidget(
        buildApp(
          Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<List<int>>(
                        MaterialPageRoute(
                          builder: (_) => EditBookListPanel.withDependencies(
                            viewModel: viewModel,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open editor'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(result, [2, 1]);
    },
  );
}
