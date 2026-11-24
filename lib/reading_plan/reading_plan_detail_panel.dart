import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/reading_plan/calendar_view.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/progress_circle.dart';
import 'package:gbt/reading_plan/reading_plan_app_bar.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

typedef NavigateToReadingPlanDetailRoute =
    Future<void> Function(BuildContext context, int planId);

class ReadingPlanDetailPanel extends StatefulWidget {
  final ReadingPlanDetailViewModel viewModel;
  final NavigateToExistingReadingPlanRoute? navigateToEditPlanRoute;
  final NavigateToDayActivityLogRoute? navigateToDayActivityLogRoute;
  final MessengerViewModel? messenger;

  const ReadingPlanDetailPanel({
    super.key,
    required this.viewModel,
    this.navigateToEditPlanRoute,
    this.navigateToDayActivityLogRoute,
    this.messenger,
  });

  static Future<void> navigateTo(
    BuildContext context,
    int planId, {
    MessengerViewModel? messenger,
  }) async {
    final messengerViewModel = messenger ?? getIt<MessengerViewModel>();
    ReadingPlanDetailViewModel viewModel;
    try {
      viewModel = await ReadingPlanDetailViewModel.create(planId: planId);
    } catch (_) {
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context)!;
      messengerViewModel.showError(l10n.errorLoadingContent);
      return;
    }

    if (!context.mounted) {
      viewModel.dispose();
      return;
    }

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ReadingPlanDetailPanel(
            viewModel: viewModel,
            messenger: messengerViewModel,
          ),
        ),
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }
  }

  @override
  State<ReadingPlanDetailPanel> createState() => ReadingPlanDetailPanelState();
}

class ReadingPlanDetailPanelState extends State<ReadingPlanDetailPanel> {
  late final ReadingPlanDetailViewModel viewModel;
  bool _openingActivityLog = false;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
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
            _appBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _appBar() {
    return ReadingPlanAppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: Text(viewModel.planName),
      onBack: () => Navigator.of(context).pop(),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: AppLocalizations.of(context)!.edit,
          onPressed: _editPlan,
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

  Future<void> _editPlan() async {
    final navigate =
        widget.navigateToEditPlanRoute ??
        (context, planId) => EditReadingPlanPanel.navigateToExisting(
          context,
          planId,
          messenger: widget.messenger,
        );
    await navigate(context, viewModel.planId);

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
    final verses = progress.verses;
    final minutes = _formatMinutes(progress.minutes);
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
      final navigate =
          widget.navigateToDayActivityLogRoute ??
          (context, date, {required readingPlanId}) =>
              DayActivityLogPanel.navigateTo(
                context,
                date,
                readingPlanId: readingPlanId,
                messenger: widget.messenger,
              );
      await navigate(context, date, readingPlanId: viewModel.planId);
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
