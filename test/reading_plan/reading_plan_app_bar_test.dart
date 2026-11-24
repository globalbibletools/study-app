import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_app_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  double appBarWidth(WidgetTester tester) =>
      tester.getSize(find.byType(AppBar)).width;

  testWidgets('keeps icon glyphs aligned with the 16px content gutter', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        ReadingPlanAppBar(
          title: const Text('Plan'),
          onBack: () {},
          actions: [
            IconButton(
              key: const Key('action'),
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final leadingButton = find.widgetWithIcon(IconButton, Icons.arrow_back);
    expect(tester.getSize(leadingButton), const Size(48, 48));
    expect(
      tester.getTopLeft(find.byIcon(Icons.arrow_back)).dx,
      closeTo(16, 0.1),
    );

    final trailingButton = find.byKey(const Key('action'));
    expect(tester.getSize(trailingButton), const Size(48, 48));
    expect(
      tester.getTopRight(find.byIcon(Icons.add)).dx,
      closeTo(appBarWidth(tester) - 16, 0.1),
    );
    expect(
      tester.getCenter(find.text('Plan')).dx,
      closeTo(appBarWidth(tester) / 2, 0.5),
    );
  });

  testWidgets('left-aligns titles after the leading slot when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        ReadingPlanAppBar(
          title: const Text('Plan'),
          centerTitle: false,
          titleSpacing: 0,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Plan')).dx, closeTo(56, 0.1));
  });
}
