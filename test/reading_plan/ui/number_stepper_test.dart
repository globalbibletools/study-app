import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/ui/number_stepper.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildStepper({
    num initialValue = 5,
    num minValue = 1,
    bool allowDecimal = false,
    ValueChanged<num>? onChanged,
  }) {
    return MaterialApp(
      home: Material(
        child: Center(
          child: NumberStepper(
            initialValue: initialValue,
            minValue: minValue,
            allowDecimal: allowDecimal,
            keyPrefix: 'test',
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('increments and decrements within bounds', (tester) async {
    final changes = <num>[];
    await tester.pumpWidget(
      buildStepper(initialValue: 5, onChanged: changes.add),
    );

    await tester.tap(find.byKey(const Key('test-increase')));
    await tester.pump();
    expect(changes, [6]);
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-decrease')));
    await tester.pump();
    expect(changes, [6, 5]);
  });

  testWidgets('accepts decimal input when enabled', (tester) async {
    final changes = <num>[];
    await tester.pumpWidget(
      buildStepper(
        initialValue: 0,
        minValue: 0,
        allowDecimal: true,
        onChanged: changes.add,
      ),
    );

    await tester.enterText(find.byType(TextField), '5.5');
    await tester.pump();

    expect(changes.last, 5.5);
    expect(find.text('5.5'), findsOneWidget);
  });
}
