import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/reading_session/rs_model.dart'
    show DailyGoal, GoalType;
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';

class ReadingSessionOverlay extends StatelessWidget {
  const ReadingSessionOverlay({super.key, required this.viewModel});

  final ReadingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: viewModel.sessionNotifier,
      builder: (context, session, _) {
        return ValueListenableBuilder(
          valueListenable: viewModel.hudVisible,
          builder: (context, displayGoalProgress, _) {
            final dailyGoal = viewModel.session?.config.dailyGoal;
            late final Widget child;
            if (session == null || dailyGoal == null) {
              child = const SizedBox.shrink(key: ValueKey('hidden'));
            } else if (!displayGoalProgress) {
              child = _CollapsedGoalProgress(
                key: const ValueKey('collapsed'),
                viewModel: viewModel,
              );
            } else if (dailyGoal.type == GoalType.verses) {
              child = _VersesGoalProgressBar(
                key: const ValueKey('verses-progress'),
                viewModel: viewModel,
                dailyGoal: dailyGoal,
                versesToday: session.versesToday,
              );
            } else {
              child = _MinutesGoalProgressBar(
                key: const ValueKey('minutes-progress'),
                viewModel: viewModel,
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
                      alignment: Alignment(axisAlignment, 0),
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
  const _CollapsedGoalProgress({super.key, required this.viewModel});

  final ReadingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: _GoalProgressToggleButton(
          label: l10n.show.toUpperCase(),
          icon: Icons.arrow_drop_down,
          onTap: () {
            viewModel.hudVisible.value = true;
          },
        ),
      ),
    );
  }
}

class _VersesGoalProgressBar extends StatelessWidget {
  const _VersesGoalProgressBar({
    super.key,
    required this.viewModel,
    required this.dailyGoal,
    required this.versesToday,
  });

  final DailyGoal dailyGoal;
  final ReadingSessionViewModel viewModel;
  final int versesToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = math.min(1, versesToday / dailyGoal.value);
    final verseLabel = l10n.versesShort;

    return _ProgressContainer(
      viewModel: viewModel,
      progressText: '$versesToday $verseLabel',
      goalText: '${dailyGoal.value} $verseLabel',
      progress: progress.toDouble(),
    );
  }
}

class _MinutesGoalProgressBar extends StatelessWidget {
  const _MinutesGoalProgressBar({
    super.key,
    required this.viewModel,
    required this.dailyGoal,
  });

  final DailyGoal dailyGoal;
  final ReadingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<int>(
      valueListenable: viewModel.secondsTodayNotifier,
      builder: (context, totalSeconds, _) {
        final progress = math.min(1, totalSeconds / 60 / dailyGoal.value);

        return _ProgressContainer(
          viewModel: viewModel,
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
    required this.viewModel,
    required this.progressText,
    required this.goalText,
    required this.progress,
  });

  final ReadingSessionViewModel viewModel;
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
                backgroundColor: primaryColor.withAlpha(51),
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
          _GoalProgressToggleButton(
            label: l10n.hide.toUpperCase(),
            icon: Icons.arrow_drop_up,
            onTap: () {
              viewModel.hudVisible.value = false;
            },
          ),
        ],
      ),
    );
  }
}

class _GoalProgressToggleButton extends StatelessWidget {
  const _GoalProgressToggleButton({
    required this.label,
    required this.onTap,
    required this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: primaryColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            Icon(icon, color: primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}
