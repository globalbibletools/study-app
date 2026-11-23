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
  final int planId;
  final ReadingPlanDetailViewModel? viewModel;
  final Widget Function(BuildContext context, ReadingPlanDetails plan)?
  editPlanBuilder;
  final DayActivityLogNavigator? dayActivityLogNavigator;

  const ReadingPlanDetailPanel({
    super.key,
    required this.planId,
    this.editPlanBuilder,
    this.dayActivityLogNavigator,
  }) : viewModel = null;

  const ReadingPlanDetailPanel.withDependencies({
    super.key,
    required this.viewModel,
    this.editPlanBuilder,
    this.dayActivityLogNavigator,
  }) : planId = 0;

  @override
  State<ReadingPlanDetailPanel> createState() => ReadingPlanDetailPanelState();
}

class ReadingPlanDetailPanelState extends State<ReadingPlanDetailPanel> {
  late final ReadingPlanDetailViewModel viewModel;
  bool _openingActivityLog = false;

  @override
  void initState() {
    super.initState();
    viewModel =
        widget.viewModel ?? ReadingPlanDetailViewModel(planId: widget.planId);
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
        if (viewModel.loadError != null) {
          content = Center(
            child: Text(
              AppLocalizations.of(context)!.errorLoadingContent,
              textAlign: TextAlign.center,
            ),
          );
        } else if (!viewModel.isInitialized) {
          content = const Center(child: CircularProgressIndicator());
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
    final plan = viewModel.planDetails;
    final routeBuilder = widget.editPlanBuilder;
    if (routeBuilder != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => routeBuilder(context, plan)),
      );
    } else {
      await EditReadingPlanPanel.navigateToExisting(context, plan);
    }

    if (!mounted) return;
    await viewModel.refresh();
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
      percent: viewModel.overallProgress,
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
    final minutes = _formatMinutes(progress?.minutes ?? 0);
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
      percent: viewModel.todaysGoalProgress,
      secondLine: versesText,
      thirdLine: minutesText,
    );
  }

  String _formatMinutes(double minutes) {
    final rounded = (minutes * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  Widget _progressSummary({
    required String title,
    required double percent,
    required String secondLine,
    required String thirdLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 16,
      children: [
        ProgressCircle(percent: percent),
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: books.length,
      itemBuilder: (context, index) => _bookRow(books[index]),
    );
  }

  Widget _bookRow(ReadingPlanBook book) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(book.bookId),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              bookNameFromId(context, book.bookId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ProgressCircle(
            percent: viewModel.progressForBook(book.bookId),
            size: 36,
            strokeWidth: 4,
            fontSize: 10,
          ),
        ],
      ),
    );
  }

  Future<void> _openDayActivityLog(int day) async {
    if (_openingActivityLog) return;

    final date = DateTime(
      viewModel.visibleMonth.year,
      viewModel.visibleMonth.month,
      day,
    );

    _openingActivityLog = true;
    try {
      final navigator = widget.dayActivityLogNavigator;
      if (navigator != null) {
        await navigator(context, date);
      } else {
        await DayActivityLogPanel.navigateTo(
          context,
          date,
          readingPlanId: viewModel.planId,
        );
      }
    } finally {
      _openingActivityLog = false;
    }

    if (!mounted) return;
    await viewModel.refresh();
  }

  Widget _goalsContentByMonth() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CalendarView(
          month: viewModel.visibleMonth,
          progressByDay: viewModel.calendarProgress,
          onPreviousMonth: () => unawaited(viewModel.showPreviousMonth()),
          onNextMonth: () => unawaited(viewModel.showNextMonth()),
          onDayTap: _openDayActivityLog,
        ),
      ),
    );
  }
}
