import 'package:flutter/material.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/service_locator.dart';

class ReadingSessionTimerView extends StatefulWidget {
  const ReadingSessionTimerView({super.key});

  @override
  State<ReadingSessionTimerView> createState() =>
      _ReadingSessionTimerViewState();
}

class _ReadingSessionTimerViewState extends State<ReadingSessionTimerView> {
  final _readingSessionManager = getIt<ReadingSessionManager>();


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        _readingSessionManager.toggleDisplayGoalProgress();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder(
              valueListenable:
                  _readingSessionManager.totalSecondsReadPerSession,
              builder: (context, elapsedSeconds, _) {
                return Text(
                  _formatDuration(elapsedSeconds),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int elapsedSeconds) {
    final int hours, minutes, seconds;

    hours = elapsedSeconds ~/ 3600;
    final remainingMinutes = elapsedSeconds.remainder(3600);
    minutes = remainingMinutes ~/ 60;
    seconds = remainingMinutes.remainder(60);

    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return "$hh:$mm:$ss";
    } else {
      return "$mm:$ss";
    }
  }
}
