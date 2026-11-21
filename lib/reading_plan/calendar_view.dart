import 'package:material_ui/material_ui.dart';

class CalendarView extends StatelessWidget {
  final DateTime month;
  final Map<int, bool> checkedDays;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<int> onDayTap;

  const CalendarView({
    super.key,
    required this.month,
    required this.checkedDays,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = daysInMonth + (firstWeekday - 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        _monthHeader(context),
        GridView.builder(
          itemCount: totalCells,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = index - (firstWeekday - 2);
            if (day <= 0 || day > daysInMonth) {
              return const SizedBox.shrink();
            }

            return _dayCalendar(context, day);
          },
        ),
      ],
    );
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPreviousMonth,
        ),
        Text(
          MaterialLocalizations.of(context).formatMonthYear(month),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNextMonth,
        ),
      ],
    );
  }

  Widget _dayCalendar(BuildContext context, int day) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;
    final isChecked = checkedDays[day] ?? false;

    final now = DateTime.now();
    final isToday =
        month.year == now.year && month.month == now.month && day == now.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap(day),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: isChecked ? color : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: isToday
              ? Border.all(color: colorScheme.onSurface, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: isChecked
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (isChecked)
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(
                  Icons.check_rounded,
                  color: colorScheme.onPrimary,
                  size: 18,
                  weight: 700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
