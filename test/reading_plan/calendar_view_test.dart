import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/calendar_view.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
  );

  Widget buildCalendar({
    DateTime? month,
    Map<int, double> progressByDay = const {},
    ThemeData? themeData,
    VoidCallback? onPreviousMonth,
    VoidCallback? onNextMonth,
    ValueChanged<int>? onDayTap,
  }) {
    return MaterialApp(
      theme: themeData ?? theme,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 500,
          child: CalendarView(
            month: month ?? DateTime(2026, 11, 1),
            progressByDay: progressByDay,
            onPreviousMonth: onPreviousMonth ?? () {},
            onNextMonth: onNextMonth ?? () {},
            onDayTap: onDayTap ?? (_) {},
          ),
        ),
      ),
    );
  }

  BoxDecoration dayDecoration(WidgetTester tester, int number) {
    final container = tester.widget<Container>(
      find.byKey(ValueKey('calendar-day-$number')),
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('renders a check for reached days and a percent below the goal', (
    tester,
  ) async {
    await tester.pumpWidget(buildCalendar(progressByDay: {5: 1, 6: 0.42}));

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);
  });

  testWidgets('days without an entry render neither a check nor a percentage', (
    tester,
  ) async {
    await tester.pumpWidget(buildCalendar(progressByDay: const {}));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('interpolates day color from default to the goal color', (
    tester,
  ) async {
    final defaultColor = theme.colorScheme.surfaceContainerLow;
    final goalColor = theme.colorScheme.primary;

    await tester.pumpWidget(buildCalendar(progressByDay: {5: 1, 6: 0.42}));

    expect(dayDecoration(tester, 7).color, defaultColor);
    expect(
      dayDecoration(tester, 6).color,
      Color.lerp(defaultColor, goalColor, 0.42),
    );
    expect(dayDecoration(tester, 5).color, goalColor);
  });

  testWidgets('keeps a visible border around today', (tester) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);

    await tester.pumpWidget(buildCalendar(month: month));

    final border = dayDecoration(tester, now.day).border! as Border;
    expect(border.top.color, theme.colorScheme.onSurface);
    expect(border.top.width, 2);
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
