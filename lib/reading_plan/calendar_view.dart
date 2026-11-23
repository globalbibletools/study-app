import 'package:material_ui/material_ui.dart';

class CalendarView extends StatelessWidget {
  final DateTime month;
  final Map<int, double> progressByDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<int> onDayTap;

  const CalendarView({
    super.key,
    required this.month,
    required this.progressByDay,
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

            return _dayCalendar(context, day, progressByDay[day]);
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

  Widget _dayCalendar(BuildContext context, int day, double? progress) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultColor = colorScheme.surfaceContainerLow;
    final goalColor = colorScheme.primary;
    final hasSession = progress != null;
    final fraction = (progress ?? 0).clamp(0.0, 1.0);
    final goalReached = hasSession && fraction == 1.0;
    final background = hasSession
        ? Color.lerp(defaultColor, goalColor, fraction)!
        : defaultColor;
    final foreground = _foregroundFor(
      colorScheme,
      background,
      hasSession: hasSession,
    );

    final now = DateTime.now();
    final isToday =
        month.year == now.year && month.month == now.month && day == now.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap(day),
      child: Container(
        key: ValueKey('calendar-day-$day'),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: background,
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
                  color: foreground,
                ),
              ),
            ),
            if (hasSession && goalReached)
              Positioned(
                bottom: 0,
                right: 0,
                child: Icon(
                  Icons.check_rounded,
                  color: foreground,
                  size: 18,
                  weight: 700,
                ),
              )
            else if (hasSession)
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  '${(fraction * 100).round()}%',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Picks whichever foreground stays readable against the interpolated
  /// background.
  Color _foregroundFor(
    ColorScheme colorScheme,
    Color background, {
    required bool hasSession,
  }) {
    if (!hasSession) return colorScheme.onSurface;

    final onSurfaceContrast = _contrastRatio(background, colorScheme.onSurface);
    final onPrimaryContrast = _contrastRatio(background, colorScheme.onPrimary);
    return onPrimaryContrast >= onSurfaceContrast
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
  }

  double _contrastRatio(Color a, Color b) {
    final aLuminance = a.computeLuminance();
    final bLuminance = b.computeLuminance();
    final lighter = aLuminance > bLuminance ? aLuminance : bLuminance;
    final darker = aLuminance > bLuminance ? bLuminance : aLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
