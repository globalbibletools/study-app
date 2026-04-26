import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';

class ReadingSessionOverlay extends StatelessWidget {
  const ReadingSessionOverlay({super.key, required this.manager});

  final ReadingSessionManager manager;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: manager.readingModeNotifier,
      builder: (context, readingModeEnabled, _) {
        return ValueListenableBuilder(
          valueListenable: manager.displayGoalProgresNotifier,
          builder: (context, displayGoalProgress, _) {
            final dailyGoal = manager.getDailyGoal();
            if (!readingModeEnabled || !displayGoalProgress) {
              return const SizedBox.shrink();
            } else if (dailyGoal.type == GoalType.verses) {
              return _VersesGoalProgressBar(
                manager: manager,
                dailyGoal: dailyGoal,
              );
            } else {
              return _MinutesGoalProgressBar(
                manager: manager,
                dailyGoal: dailyGoal,
              );
            }
          },
        );
      },
    );
  }
}

class _VersesGoalProgressBar extends StatelessWidget {
  const _VersesGoalProgressBar({
    required this.manager,
    required this.dailyGoal,
  });

  final DailyGoal dailyGoal;
  final ReadingSessionManager manager;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<int>(
      valueListenable: manager.totalVersesReadPerDay,
      builder: (context, totalVerses, _) {
        final progress = math.min(1, totalVerses / dailyGoal.value);
        final verseLabel = l10n.versesShort;

        return _ProgressContainer(
          manager: manager,
          progressText: '$totalVerses $verseLabel',
          goalText: '${dailyGoal.value} $verseLabel',
          progress: progress.toDouble(),
        );
      },
    );
  }
}

class _MinutesGoalProgressBar extends StatelessWidget {
  const _MinutesGoalProgressBar({
    required this.manager,
    required this.dailyGoal,
  });

  final DailyGoal dailyGoal;
  final ReadingSessionManager manager;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<int>(
      valueListenable: manager.totalSecondsReadPerDay,
      builder: (context, totalSeconds, _) {
        final progress = math.min(1, totalSeconds / 60 / dailyGoal.value);

        return _ProgressContainer(
          manager: manager,
          progressText: _formatSeconds(totalSeconds),
          goalText: '${dailyGoal.value} ${l10n.minutesShort}',
          progress: progress.toDouble(),
        );
      },
    );
  }

  String _formatSeconds(int seconds) {
    final s = seconds % 60;
    final m = seconds ~/ 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
}

class _ProgressContainer extends StatelessWidget {
  const _ProgressContainer({
    required this.manager,
    required this.progressText,
    required this.goalText,
    required this.progress,
  });

  final ReadingSessionManager manager;
  final String progressText;
  final String goalText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: backgroundColor,
      child: Row(
        children: [
          Text(
            progressText,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: primaryColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            goalText,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Icon(Icons.adjust, color: primaryColor),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              manager.displayGoalProgresNotifier.value = false;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: primaryColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${l10n.hide.toUpperCase()} >',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
