import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

class CalendarView<E, T extends List<E>> extends StatefulWidget {
  final ValueListenable<T> value;
  final void Function(E) onTap;
  final bool Function(E) isHighlighted;

  final EdgeInsets padding;

  final void Function(DateTime month)? onMonthChanged;

  final DateTime? initialMonth;

  const CalendarView({
    super.key,
    required this.value,
    required this.onTap,
    required this.isHighlighted,
    this.padding = const EdgeInsets.all(8),
    this.onMonthChanged,
    this.initialMonth,
  });

  @override
  State<CalendarView<E, T>> createState() => _CalendarViewState<E, T>();
}

class _CalendarViewState<E, T extends List<E>>
    extends State<CalendarView<E, T>> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final init = widget.initialMonth ?? DateTime.now();
    _displayedMonth = DateTime(init.year, init.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
    widget.onMonthChanged?.call(_displayedMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [_monthHeader(context), _buildCalendar()],
    );
  }

  Widget _monthHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(-1),
        ),
        Text(
          MaterialLocalizations.of(context).formatMonthYear(_displayedMonth),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return ValueListenableBuilder<T>(
      valueListenable: widget.value,
      builder: (ctx, data, _) {
        if (data.isEmpty) {
          return const SizedBox.shrink();
        }

        final firstDay = DateTime(
          _displayedMonth.year,
          _displayedMonth.month,
          1,
        );
        final daysInMonth = DateTime(
          _displayedMonth.year,
          _displayedMonth.month + 1,
          0,
        ).day;

        final firstWeekday = firstDay.weekday; // 1 = Mon

        // Pad cells for the first week up to the first day.
        final totalCells = daysInMonth + (firstWeekday - 1);

        return GridView.builder(
          itemCount: totalCells,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = index - (firstWeekday - 2);
            if (day <= 0 || day - 1 >= data.length) {
              return const SizedBox.shrink();
            }

            final entry = data[day - 1];

            return _dayCalendar(day, entry);
          },
        );
      },
    );
  }

  Widget _dayCalendar(int day, E entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.primary;
    final bool isHighlighted = widget.isHighlighted(entry);

    final now = DateTime.now();
    final isToday =
        _displayedMonth.year == now.year &&
        _displayedMonth.month == now.month &&
        day == now.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(entry),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: isHighlighted ? color : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: isToday
              ? Border.all(color: color, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                "$day",
                style: TextStyle(
                  fontSize: 12,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (isHighlighted)
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
