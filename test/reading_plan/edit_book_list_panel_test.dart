import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/edit_book_list_panel.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  testWidgets('shows the Customize Books heading and bold Save button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(const Scaffold(body: EditBookListPanel(bookIds: [1, 2]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Customize Books'), findsOneWidget);
    expect(find.text('Books in this Plan'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Save')).style?.fontWeight,
      FontWeight.bold,
    );
  });

  testWidgets('scrolls to a newly appended book', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: EditBookListPanel(bookIds: [for (int i = 1; i <= 30; i++) i]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Obadiah'), findsNothing);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obadiah').last);
    await tester.pumpAndSettle();

    expect(find.text('Obadiah'), findsOneWidget);
  });

  testWidgets('removes books, appends unselected books, and returns the list', (
    tester,
  ) async {
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
                        builder: (_) =>
                            const EditBookListPanel(bookIds: [1, 2]),
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

    expect(find.text('Customize Books'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(find.byKey(const ValueKey(2)), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));

    final genesisRow = find.byKey(const ValueKey(1));
    await tester.tap(
      find.descendant(of: genesisRow, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();

    expect(find.text('Genesis'), findsNothing);
    expect(find.text('Exodus'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Genesis').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey(2))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey(1))).dy),
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, [2, 1]);
  });
}
