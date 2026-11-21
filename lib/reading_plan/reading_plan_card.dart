import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/delete_reading_plan_confirm_dialog.dart';
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
      margin: const EdgeInsets.only(bottom: 16),
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
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 16,
              children: [
                _progressText(context),
                Flexible(child: _resumeButton(context)),
              ],
            ),
          ],
        ),
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

  Widget _progressText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalVerses = plan.totalVerses > 0 ? plan.totalVerses : 1;
    final progress = plan.versesRead / totalVerses;
    final percent = (progress * 100).toInt();

    return Text(
      '${plan.versesRead}/$totalVerses ${l10n.verses} · $percent%',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
