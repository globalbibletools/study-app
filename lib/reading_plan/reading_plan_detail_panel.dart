import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/ui/home/panel_area/common/calendar_view.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';

class ReadingPlanDetailPanel extends StatefulWidget {
  final ReadingPlanDetails readingPlanDetails;
  final Function onClose;

  const ReadingPlanDetailPanel({
    super.key,
    required this.readingPlanDetails,
    required this.onClose,
  });

  @override
  State<ReadingPlanDetailPanel> createState() => ReadingPlanDetailPanelState();
}

class ReadingPlanDetailPanelState extends State<ReadingPlanDetailPanel> {
  late final ReadingPlanDetailViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = ReadingPlanDetailViewModel(plan: widget.readingPlanDetails);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox.expand(
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                return Column(
                  children: [
                    _handle(),
                    const SizedBox(height: 16),
                    _topTitle(),
                    const SizedBox(height: 12),
                    Expanded(child: _content()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Text(
          viewModel.planName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      // While reordering, the ReorderableListView drives its own scrolling
      // via its shrink-wrapped, non-scrollable physics below.
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _progressHeader(),
          const SizedBox(height: 16),
          _startResumeButton(),
          const SizedBox(height: 16),
          _statsRow(),
          const SizedBox(height: 30),
          _goalsContentByMonth(),
          const SizedBox(height: 20),
          _booksHeader(),
          const SizedBox(height: 12),
          _booksList(),
        ],
      ),
    );
  }

  Widget _progressHeader() {
    final progressPercent = viewModel.progressPercent;
    final l10n = AppLocalizations.of(context)!;
    final resumePosition = viewModel.resumePosition;

    final Widget progressWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.booksReadOfTotal(viewModel.booksRead, viewModel.books.length),
        ),
        const SizedBox(height: 4),
        if (resumePosition != null) ...[
          Text(
            l10n.current,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 2),
          Text(
            '${bookNameFromId(context, resumePosition.bookId)} ${resumePosition.chapter}',
          ),
        ],
      ],
    );

    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: viewModel.overallProgress,
                strokeWidth: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
            Text(
              "$progressPercent%",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(child: progressWidget),
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

  Widget _startResumeButton() {
    final l10n = AppLocalizations.of(context)!;

    final txt = viewModel.versesRead == 0
        ? l10n.startReading
        : l10n.resumeReading;

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

          widget.onClose();
        },
        icon: const Icon(Icons.play_arrow),
        label: Text(txt),
      ),
    );
  }

  Widget _statsRow() {
    final l10n = AppLocalizations.of(context)!;

    final goalType = viewModel.goalType;

    String goalTxt = goalType == GoalType.minutes
        ? l10n.minutesPerDay.toLowerCase()
        : l10n.versesPerDay.toLowerCase();

    final target = viewModel.goalValue;
    final progress = viewModel.todaysProgress;

    String progressStr;
    if (progress == null) {
      progressStr = '0/$target';
    } else if (goalType == GoalType.verses) {
      progressStr = '${progress.verses}/$target';
    } else {
      progressStr = '${progress.minutes}/$target';
    }

    final progressValue = viewModel.todaysGoalProgress
        .clamp(0.0, 1.0)
        .toDouble();

    final todaysProgress = Column(
      children: [
        Text('$target $goalTxt'),
        SizedBox(height: 8),

        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: progressValue,
                strokeWidth: 6,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
            Text(progressStr, style: const TextStyle(fontSize: 10)),
          ],
        ),

        const SizedBox(height: 4),
        if (viewModel.goalReachedToday) Text(l10n.completedToday),
      ],
    );

    return Row(
      children: [
        Expanded(
          child: _statCard(title: l10n.todaysGoal, child: todaysProgress),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: l10n.estimatedCompletion,
            child: _estimatedCompletionContent(),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return '${l10n.months(date.month.toString())} ${date.day}, ${date.year}';
  }

  Widget _estimatedCompletionContent() {
    final l10n = AppLocalizations.of(context)!;

    if (!viewModel.hasEstimate) {
      return Text(l10n.planComplete, style: const TextStyle(fontSize: 16));
    }

    return Column(
      children: [
        Text(
          l10n.daysCount(viewModel.estimatedDays),
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(l10n.monthsCount(viewModel.estimatedMonths.toStringAsFixed(1))),
        const SizedBox(height: 4),
        Text(_formatDate(viewModel.estimatedCompletionDate)),
      ],
    );
  }

  Widget _statCard({required String title, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
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
        readingPlanId: widget.readingPlanDetails.readingPlan.id!,
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
  final bool reorderable;

  const _BookRow({
    required this.name,
    required this.progress,
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
            progress == 1.0 ? Icons.check_circle : Icons.circle_outlined,
            color: progress == 1.0 ? colorScheme.primary : colorScheme.outline,
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
