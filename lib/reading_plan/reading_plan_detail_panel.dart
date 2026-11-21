import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/ui/home/panel_area/common/calendar_view.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
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
        return Column(
          children: [
            _topBar(),
            const SizedBox(height: 12),
            Expanded(child: _content()),
          ],
        );
      },
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            viewModel.planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: Icon(
            viewModel.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          ),
          onPressed: () {
            viewModel.toggleBookmark();
          },
        ),
      ],
    );
  }

  Widget _content() {
    if (!viewModel.isInitialized) {
      if (viewModel.loadError != null) {
        return Center(
          child: Text(
            AppLocalizations.of(context)!.errorLoadingContent,
            textAlign: TextAlign.center,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (viewModel.isRefreshing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: SingleChildScrollView(
            // While reordering, the ReorderableListView drives its own
            // scrolling via its shrink-wrapped, non-scrollable physics below.
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _startResumeButton(),
                const SizedBox(height: 20),
                _totalProgress(),
                const SizedBox(height: 20),
                _todaysProgress(),
                const SizedBox(height: 30),
                _goalsContentByMonth(),
                const SizedBox(height: 20),
                _booksHeader(),
                const SizedBox(height: 12),
                _booksList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalProgress() {
    final l10n = AppLocalizations.of(context)!;
    final completion = viewModel.hasEstimate
        ? '${l10n.daysRemaining(viewModel.estimatedDays)} '
              '(${_formatDate(viewModel.estimatedCompletionDate)})'
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: () async {
          await viewModel.startReadingSession();

          if (!mounted) return;

          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(txt),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(secondLine),
              Text(thirdLine),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return '${l10n.months(date.month.toString())} ${date.day}, ${date.year}';
  }

  Widget _booksHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.booksInThisPlan),
        GestureDetector(
          onTap: () {
            viewModel.toggleReorderMode();
          },
          child: Text(
            viewModel.isReorderMode
                ? AppLocalizations.of(context)!.done
                : AppLocalizations.of(context)!.editOrder,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
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

    if (viewModel.isReorderMode) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: books.length,
        onReorderItem: viewModel.moveBook,
        itemBuilder: (context, index) {
          final book = books[index];

          return ReorderableDragStartListener(
            key: ValueKey(book.bookId),
            index: index,
            child: _BookRow(
              name: bookNameFromId(context, book.bookId),
              progress: viewModel.progressForBook(book.bookId),
              complete: viewModel.isBookComplete(book.bookId),
              reorderable: true,
            ),
          );
        },
      );
    }

    return Column(
      children: books.map((book) {
        return _BookRow(
          name: bookNameFromId(context, book.bookId),
          progress: viewModel.progressForBook(book.bookId),
          complete: viewModel.isBookComplete(book.bookId),
        );
      }).toList(),
    );
  }

  Future<void> _openDayActivityLog(DayProgress progress) async {
    if (progress.empty) {
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

  bool isHighlighted(DayProgress progress) {
    return progress.goalReached;
  }

  Widget _goalsContentByMonth() {
    return CalendarView(
      value: viewModel.monthProgress,
      onTap: _openDayActivityLog,
      isHighlighted: isHighlighted,
      onMonthChanged: (month) => viewModel.loadMonthData(month),
      padding: EdgeInsets.all(20),
    );
  }
}

class _BookRow extends StatelessWidget {
  final String name;
  final double progress;
  final bool complete;
  final bool reorderable;

  const _BookRow({
    required this.name,
    required this.progress,
    required this.complete,
    this.reorderable = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.circle_outlined,
            color: complete ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (reorderable)
            Icon(Icons.drag_handle, color: colorScheme.onSurfaceVariant)
          else ...[
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
