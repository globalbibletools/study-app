import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/ui/progress_circle.dart';
import 'package:gbt/reading_plan/data_access/reading_plan_read_models.dart';

class ReadingPlanCard extends StatelessWidget {
  const ReadingPlanCard({
    super.key,
    required this.plan,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onStartSession,
  });

  final ReadingPlanSummary plan;
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Fixed-height box below the card that reserves the resume button's
    // overhang and keeps its full tap target inside the Stack.
    const resumeOverhangBoxHeight = 14.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 32 - resumeOverhangBoxHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Expanded(child: _planTitle(context)),
                          Transform.translate(
                            offset: const Offset(8, 0),
                            child: _planActions(context),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 16,
                        children: [
                          Flexible(child: _overallProgress(context)),
                          Flexible(child: _todayGoalProgress(context)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: resumeOverhangBoxHeight),
            ],
          ),
          if (plan.isBookmarked)
            Positioned(left: 20, top: -8, child: _bookmarkRibbon(context)),
          Positioned(right: 16, bottom: 0, child: _resumeButton(context)),
        ],
      ),
    );
  }

  Widget _bookmarkRibbon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Icon(
      Icons.bookmark,
      key: ValueKey('plan-bookmark-ribbon-${plan.planId}'),
      color: colorScheme.primary,
      size: 28,
    );
  }

  Widget _todayGoalProgress(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final today = plan.today;
    final goalReached = today.goalReached;
    final remaining =
        plan.dailyGoal.value -
        (plan.dailyGoal.type == GoalType.verses ? today.verses : today.minutes);
    final remainingCount = math.max(remaining, 0).ceil();
    final label = goalReached
        ? l10n.dailyGoalReached
        : plan.dailyGoal.type == GoalType.verses
        ? l10n.versesLeft(remainingCount)
        : l10n.minutesLeft(remainingCount);

    return Row(
      key: ValueKey('plan-daily-goal-${plan.planId}'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: 4,
      children: [
        if (goalReached)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
            child: Icon(Icons.check, color: colorScheme.primary, size: 16),
          ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _planTitle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
      onPressed: onOpenDetails,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              plan.planName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.primary, size: 20),
        ],
      ),
    );
  }

  Widget _planActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onEdit,
          tooltip: l10n.edit,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    );
  }

  Widget _overallProgress(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = plan.totalVerses > 0
        ? plan.versesRead / plan.totalVerses
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        ProgressCircle(
          percent: progress,
          size: 32,
          strokeWidth: 4,
          fontSize: 9,
        ),
        Flexible(
          child: Text(
            '${plan.versesRead}/${plan.totalVerses} ${l10n.verses}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _resumeButton(BuildContext context) {
    final resumeTarget = plan.resumeTarget;
    final bookName = bookNameFromId(context, resumeTarget.bookId);
    final resumeReference =
        '$bookName ${resumeTarget.chapter}:${resumeTarget.verse}';

    return FilledButton(
      key: ValueKey('plan-resume-${plan.planId}'),
      onPressed: onStartSession,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            resumeReference,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }
}
