import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/ui/reading_sheet.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('fills 85% of the screen height and clips its top corners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 1000)),
          child: Scaffold(body: ReadingSheet(child: const SizedBox())),
        ),
      ),
    );
    await tester.pump();

    final sizedBoxFinder = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 850.0,
    );
    expect(sizedBoxFinder, findsOneWidget);

    expect(find.byType(ClipRRect), findsWidgets);
  });
}
