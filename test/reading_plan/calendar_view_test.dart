import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/calendar_view.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildCalendar({
    DateTime? month,
    Map<int, bool> checkedDays = const {},
    VoidCallback? onPreviousMonth,
    VoidCallback? onNextMonth,
    ValueChanged<int>? onDayTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 500,
          child: CalendarView(
            month: month ?? DateTime(2026, 11, 1),
            checkedDays: checkedDays,
            onPreviousMonth: onPreviousMonth ?? () {},
            onNextMonth: onNextMonth ?? () {},
            onDayTap: onDayTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders the supplied month and checked days', (tester) async {
    await tester.pumpWidget(buildCalendar(checkedDays: {5: true}));

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('missing and false entries do not render a check', (
    tester,
  ) async {
    await tester.pumpWidget(buildCalendar(checkedDays: {5: false}));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('calls the callbacks for both month directions', (tester) async {
    var previous = 0;
    var next = 0;

    await tester.pumpWidget(
      buildCalendar(
        onPreviousMonth: () => previous++,
        onNextMonth: () => next++,
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));

    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('calls onDayTap with the tapped day', (tester) async {
    int? tappedDay;

    await tester.pumpWidget(buildCalendar(onDayTap: (day) => tappedDay = day));

    await tester.tap(find.text('14'));

    expect(tappedDay, 14);
  });
}
