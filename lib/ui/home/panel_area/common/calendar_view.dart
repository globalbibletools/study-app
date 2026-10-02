import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _monthHeader(context),
          const SizedBox(height: 12),
          _buildCalendar(),
        ],
      ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

        final totalCells = daysInMonth + (firstWeekday - 1);

        final now = DateTime.now();

        return GridView.builder(
          itemCount: totalCells,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - (firstWeekday - 2);

            // Guard against `data` having fewer entries than days in the
            // displayed month (e.g. future days not yet populated).
            if (dayNumber - 1 >= data.length) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              _displayedMonth.year,
              _displayedMonth.month,
              dayNumber,
            );
            final entry = data[dayNumber - 1];

            final isToday =
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

            return _dayCalendar(date, isToday, entry);
          },
        );
      },
    );
  }

  Widget _dayCalendar(DateTime date, bool isToday, E entry) {
    final color = Theme.of(context).colorScheme.primary;
    final bool isHighlighted = widget.isHighlighted(entry);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onTap(entry),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isHighlighted
                ? color
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: isToday ? Border.all(color: color, width: 2) : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Text(
                  "${date.day}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isHighlighted
                        ? Colors.white.withValues(alpha: 0.9)
                        : null,
                  ),
                ),
              ),
              if (isHighlighted)
                const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 42,
                    weight: 700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
