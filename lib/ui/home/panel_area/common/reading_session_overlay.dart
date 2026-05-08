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
            late final Widget child;
            if (!readingModeEnabled || dailyGoal == null) {
              child = const SizedBox.shrink(key: ValueKey('hidden'));
            } else if (!displayGoalProgress) {
              child = _CollapsedGoalProgress(
                key: const ValueKey('collapsed'),
                manager: manager,
              );
            } else if (dailyGoal.type == GoalType.verses) {
              child = _VersesGoalProgressBar(
                key: const ValueKey('verses-progress'),
                manager: manager,
                dailyGoal: dailyGoal,
              );
            } else {
              child = _MinutesGoalProgressBar(
                key: const ValueKey('minutes-progress'),
                manager: manager,
                dailyGoal: dailyGoal,
              );
            }

            final textDirection = Directionality.of(context);
            final edgeAlignment = textDirection == TextDirection.ltr
                ? Alignment.centerRight
                : Alignment.centerLeft;
            final axisAlignment = textDirection == TextDirection.ltr
                ? 1.0
                : -1.0;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              reverseDuration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: edgeAlignment,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                return Align(
                  alignment: edgeAlignment,
                  child: ClipRect(
                    child: SizeTransition(
                      axis: Axis.horizontal,
                      axisAlignment: axisAlignment,
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
                );
              },
              child: child,
            );
          },
        );
      },
    );
  }
}

class _CollapsedGoalProgress extends StatelessWidget {
  const _CollapsedGoalProgress({super.key, required this.manager});

  final ReadingSessionManager manager;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: _GoalProgressToggleButton(
          label: '< ${l10n.show}'.toUpperCase(),
          onTap: () {
            manager.displayGoalProgresNotifier.value = true;
          },
        ),
      ),
    );
  }
}

class _VersesGoalProgressBar extends StatelessWidget {
  const _VersesGoalProgressBar({
    super.key,
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
    super.key,
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
          _GoalProgressToggleButton(
            label: '${l10n.hide.toUpperCase()} >',
            onTap: () {
              manager.displayGoalProgresNotifier.value = false;
            },
          ),
        ],
      ),
    );
  }
}

class _GoalProgressToggleButton extends StatelessWidget {
  const _GoalProgressToggleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: primaryColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
