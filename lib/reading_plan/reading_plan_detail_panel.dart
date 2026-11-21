import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/calendar_view.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/progress_circle.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';

class ReadingPlanDetailPanel extends StatefulWidget {
  final ReadingPlanDetails? readingPlanDetails;
  final ReadingPlanDetailViewModel? viewModel;

  const ReadingPlanDetailPanel({
    super.key,
    required ReadingPlanDetails this.readingPlanDetails,
  }) : viewModel = null;

  const ReadingPlanDetailPanel.withDependencies({
    super.key,
    required this.viewModel,
  }) : readingPlanDetails = null;

  @override
  State<ReadingPlanDetailPanel> createState() => ReadingPlanDetailPanelState();
}

class ReadingPlanDetailPanelState extends State<ReadingPlanDetailPanel> {
  late final ReadingPlanDetailViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel =
        widget.viewModel ??
        ReadingPlanDetailViewModel(plan: widget.readingPlanDetails!);
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
        final Widget content;
        if (!viewModel.isInitialized) {
          content = viewModel.loadError != null
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.errorLoadingContent,
                    textAlign: TextAlign.center,
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        } else {
          content = Column(
            spacing: 16,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 24,
                    children: [
                      _todaysProgress(),
                      _goalsContentByMonth(),
                      Divider(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                      _totalProgress(),
                      _booksList(),
                    ],
                  ),
                ),
              ),
              _startResumeButton(),
            ],
          );
        }

        return Column(
          spacing: 16,
          children: [
            _topBar(),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _topBar() {
    const iconInset = 6.0;
    final iconStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-iconInset, 0),
          child: IconButton(
            style: iconStyle,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: Text(
            viewModel.planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        Transform.translate(
          offset: const Offset(iconInset, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                style: iconStyle,
                icon: const Icon(Icons.edit_outlined),
                tooltip: AppLocalizations.of(context)!.edit,
                onPressed: _editPlan,
              ),
              IconButton(
                style: iconStyle,
                icon: Icon(
                  viewModel.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
                onPressed: () {
                  viewModel.toggleBookmark();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editPlan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditReadingPlanPanel.existing(viewModel.planDetails),
      ),
    );

    if (!mounted) return;
    await viewModel.reloadPlan();
  }

  Widget _totalProgress() {
    final l10n = AppLocalizations.of(context)!;
    final completionDate = viewModel.estimatedCompletionDate;
    final completion = viewModel.hasEstimate
        ? '${l10n.daysRemaining(viewModel.estimatedDays)} '
              '(${l10n.months(completionDate.month.toString())} '
              '${completionDate.day}, ${completionDate.year})'
        : l10n.planComplete;

    return _progressSummary(
      title: l10n.totalProgress,
      value: viewModel.overallProgress,
      percent: viewModel.progressPercent,
      secondLine: l10n.booksReadOfTotal(
        viewModel.booksRead,
        viewModel.books.length,
      ),
      thirdLine: completion,
    );
  }

  Widget _startResumeButton() {
    final l10n = AppLocalizations.of(context)!;
    final reference = viewModel.readingReference;
    final referenceText =
        '${bookNameFromId(context, reference.bookId)} '
        '${reference.chapter}:${reference.verse}';

    final txt = viewModel.hasStarted
        ? l10n.resumeAtReference(referenceText)
        : l10n.startAtReference(referenceText);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () async {
          await viewModel.startReadingSession();

          if (!mounted) return;

          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        },
        child: Text(txt, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _todaysProgress() {
    final l10n = AppLocalizations.of(context)!;
    final progress = viewModel.todaysProgress;
    final verses = progress?.verses ?? 0;
    final minutes = progress?.minutes ?? 0;
    final target = viewModel.goalValue;
    final isVersesGoal = viewModel.goalType == GoalType.verses;

    final versesText = isVersesGoal
        ? '$verses/$target ${l10n.verses}'
        : '$verses ${l10n.verses}';
    final minutesText = isVersesGoal
        ? '$minutes ${l10n.minutes}'
        : '$minutes/$target ${l10n.minutes}';

    return _progressSummary(
      title: l10n.todaysProgress,
      value: viewModel.todaysGoalProgress,
      percent: viewModel.todaysGoalPercent,
      secondLine: versesText,
      thirdLine: minutesText,
    );
  }

  Widget _progressSummary({
    required String title,
    required double value,
    required int percent,
    required String secondLine,
    required String thirdLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 16,
      children: [
        ProgressCircle(value: value, percent: percent),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(secondLine),
              Text(thirdLine),
            ],
          ),
        ),
      ],
    );
  }

  Widget _booksList() {
    if (viewModel.bookStats.isEmpty) {
      return const SizedBox.shrink();
    }

    final books = viewModel.books;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: books.length,
      onReorderItem: viewModel.moveBook,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(color: Colors.transparent, elevation: 0, child: child);
      },
      itemBuilder: (context, index) {
        final book = books[index];

        return _BookRow(
          key: ValueKey(book.bookId),
          index: index,
          name: bookNameFromId(context, book.bookId),
          progress: viewModel.progressForBook(book.bookId),
        );
      },
    );
  }

  Future<void> _openDayActivityLog(int day) async {
    final progress = viewModel.dayProgress(day);
    if (progress == null || progress.empty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => DayActivityLogPanel(
        readingPlanId: viewModel.planId,
        date: progress.day,
      ),
    );
  }

  Widget _goalsContentByMonth() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CalendarView(
          month: viewModel.visibleMonth,
          checkedDays: viewModel.checkedDays,
          onPreviousMonth: () => unawaited(viewModel.showPreviousMonth()),
          onNextMonth: () => unawaited(viewModel.showNextMonth()),
          onDayTap: _openDayActivityLog,
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final int index;
  final String name;
  final double progress;

  const _BookRow({
    super.key,
    required this.index,
    required this.name,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ProgressCircle(
            value: progress,
            percent: (progress * 100).toInt(),
            size: 36,
            strokeWidth: 4,
            fontSize: 10,
          ),
        ],
      ),
    );
  }
}
