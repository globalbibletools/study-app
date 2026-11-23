import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/delete_reading_plan_confirm_dialog.dart';
import 'package:gbt/reading_plan/progress_circle.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class ReadingPlanCard extends StatelessWidget {
  const ReadingPlanCard({
    super.key,
    required this.plan,
    required this.onOpenDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onStartSession,
  });

  final ReadingPlanDetails plan;
  final VoidCallback onOpenDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Stack(
        clipBehavior: Clip.none,
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
                      Flexible(child: _resumeButton(context)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (plan.readingPlan.isBookmarked)
            Positioned(left: -8, top: 16, child: _bookmarkRibbon(context)),
          Positioned(left: 16, bottom: -12, child: _dailyGoalLabel(context)),
        ],
      ),
    );
  }

  Widget _bookmarkRibbon(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.rotate(
      key: ValueKey('plan-bookmark-ribbon-${plan.readingPlan.id}'),
      angle: math.pi / 2,
      child: Icon(Icons.bookmark, color: colorScheme.primary, size: 28),
    );
  }

  Widget _dailyGoalLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final today = plan.todayProgress;
    final goalReached = today?.goalReached ?? false;
    final remaining =
        plan.dailyGoal.value -
        (plan.dailyGoal.type == GoalType.verses
            ? today?.verses ?? 0
            : today?.minutes ?? 0);
    final label = goalReached
        ? l10n.dailyGoalReached
        : plan.dailyGoal.type == GoalType.verses
        ? l10n.versesLeft(math.max(remaining, 0))
        : l10n.minutesLeft(math.max(remaining, 0));

    return Container(
      key: ValueKey('plan-daily-goal-${plan.readingPlan.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (goalReached)
            Icon(Icons.check, color: colorScheme.onPrimary, size: 12),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
              plan.readingPlan.planName,
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
    final colorScheme = Theme.of(context).colorScheme;

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
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () => _deletePlan(context),
          tooltip: l10n.deleteReadingPlan,
          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
        ),
      ],
    );
  }

  Widget _overallProgress(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalVerses = plan.totalVerses > 0 ? plan.totalVerses : 1;
    final progress = plan.versesRead / totalVerses;
    final versesLeft = math.max(plan.totalVerses - plan.versesRead, 0);

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
            l10n.versesLeft(versesLeft),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _resumeButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resumeTarget =
        plan.resumePosition ??
        Reference(
          bookId: plan.books.isNotEmpty ? plan.books.first.bookId : 1,
          chapter: 1,
          verse: 1,
        );
    final bookName = bookNameFromId(context, resumeTarget.bookId);
    final resumeReference =
        '$bookName ${resumeTarget.chapter}:${resumeTarget.verse}';

    return TextButton(
      onPressed: onStartSession,
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              l10n.resumeAtReference(resumeReference),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.primary, size: 14),
        ],
      ),
    );
  }

  Future<void> _deletePlan(BuildContext context) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteReadingPlanConfirmDialog(planName: plan.readingPlan.planName),
    );
    if (confirmed != true) return;

    onDelete();
  }
}
