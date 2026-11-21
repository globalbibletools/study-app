import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class ReadingPlanPanel extends StatefulWidget {
  final Function onClose;

  const ReadingPlanPanel({super.key, required this.onClose});

  @override
  State<ReadingPlanPanel> createState() => ReadingPlanPanelState();
}

class ReadingPlanPanelState extends State<ReadingPlanPanel> {
  late final ReadingPlanPanelViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = ReadingPlanPanelViewModel();
    unawaited(viewModel.initialize());
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return SizedBox.expand(
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _handle(),
                  const SizedBox(height: 16),
                  _topTitle(),
                  const SizedBox(height: 12),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _handle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _topTitle() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.readingPlans,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _content() {
    if (!viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Scrollable list, padded at the bottom so the last
        // card isn't hidden behind the floating button.
        ListView(
          padding: const EdgeInsets.only(bottom: 76),
          children: viewModel.plans.map(_readingPlan).toList(),
        ),
        // Floating "Create New Plan" button.
        Positioned(left: 0, right: 0, bottom: 0, child: _createNewPlanButton()),
      ],
    );
  }

  Widget _createNewPlanButton() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EditReadingPlanPanel.newPlan(l10n.defaultReadingPlanName),
            ),
          );

          await viewModel.refresh();
        },
        child: Text(
          l10n.createNewPlan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _readingPlan(ReadingPlanDetails planDet) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.09),
      colorScheme.surface,
    );

    final totalVerses = planDet.totalVerses > 0 ? planDet.totalVerses : 1;
    final progress = planDet.versesRead / totalVerses;
    final percent = (progress * 100).toInt();
    final resumeTarget = _resumeTargetFor(planDet);
    final resumeReference = _referenceLabel(resumeTarget);
    final progressText =
        '${planDet.versesRead}/$totalVerses ${l10n.verses} · $percent%';
    const progressStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    final resumeStyle = TextStyle(
      color: colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    planDet.readingPlan.planName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(8, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _editPlan(planDet),
                        tooltip: l10n.edit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _deletePlan(planDet),
                        tooltip: l10n.deleteReadingPlan,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 16,
              children: [
                Text(progressText, style: progressStyle),
                Flexible(
                  child: TextButton(
                    onPressed: () => _startReadingSession(planDet),
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
                            style: resumeStyle,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Reference _resumeTargetFor(ReadingPlanDetails planDet) {
    final resumePosition = planDet.resumePosition;
    if (resumePosition != null) return resumePosition;

    if (planDet.books.isNotEmpty) {
      return Reference(
        bookId: planDet.books.first.bookId,
        chapter: 1,
        verse: 1,
      );
    }

    return const Reference(bookId: 1, chapter: 1, verse: 1);
  }

  String _referenceLabel(Reference reference) {
    final bookName = bookNameFromId(context, reference.bookId);
    return '$bookName ${reference.chapter}:${reference.verse}';
  }

  Future<void> _editPlan(ReadingPlanDetails planDet) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditReadingPlanPanel.existing(planDet)),
    );

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _deletePlan(ReadingPlanDetails planDet) async {
    final planId = planDet.readingPlan.id;
    if (planId == null) return;

    final confirmed = await confirmDeleteReadingPlan(
      context,
      planDet.readingPlan.planName,
    );
    if (!confirmed) return;

    await viewModel.deletePlan(planId);
  }

  Future<void> _startReadingSession(ReadingPlanDetails planDet) async {
    await viewModel.startReadingSession(planDet);

    if (!mounted) return;
    widget.onClose();
  }
}

Future<bool> confirmDeleteReadingPlan(
  BuildContext context,
  String planName,
) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.deleteReadingPlanConfirmTitle),
        content: Text(l10n.deleteReadingPlanConfirmMessage(planName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
