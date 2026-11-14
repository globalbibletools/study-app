import 'package:flutter/material.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/book_names.dart';
import 'package:gbt/services/reading_session/rs_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/panel_area/common/calendar_view.dart';
import 'package:gbt/ui/home/reading_plan/reading_plan_detail_panel_manager.dart';
import 'package:gbt/ui/home/reading_plan/detailed_progress_panel.dart';

class ReadingPlanDetailPanel extends StatefulWidget {
  final ReadingPlanDetails readingPlanDetails;
  final HomeManager homeManager;
  final Function onClose;

  const ReadingPlanDetailPanel({
    super.key,
    required this.readingPlanDetails,
    required this.homeManager,
    required this.onClose,
  });

  @override
  State<ReadingPlanDetailPanel> createState() => ReadingPlanDetailPanelState();
}

class ReadingPlanDetailPanelState extends State<ReadingPlanDetailPanel> {
  late final _bibleNavigation = getIt<BibleNavigation>();
  late final ReadingPlanDetailPanelManager manager;

  /// Local, reorderable copy of the plan's books. Seeded from the widget and
  /// kept in sync with drag-and-drop reordering while `_reorderMode` is on.
  late List<ReadingPlanBook> _books;

  bool _reorderMode = false;

  /// Rough average reading pace, used only to convert a minutes-based daily
  /// goal into an equivalent verses-per-day figure for the estimate below.
  /// This is an approximation — swap in a measured pace from reading
  /// sessions if/when that data is available.
  static const double _estimatedVersesPerMinute = 8;

  @override
  void initState() {
    super.initState();
    manager = ReadingPlanDetailPanelManager(widget.readingPlanDetails);
    _books = List.of(widget.readingPlanDetails.books);
  }

  /// Re-reads the font scale from persisted settings into the notifier.
  void refreshFromSettings() {}

  @override
  void didUpdateWidget(covariant ReadingPlanDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    manager.dispose();
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
          widget.readingPlanDetails.readingPlan.planName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      // While reordering, the ReorderableListView drives its own scrolling
      // via NeverScrollableScrollPhysics below, so nesting here stays safe.
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
    final progress = widget.readingPlanDetails.totalVerses > 0
        ? widget.readingPlanDetails.versesRead /
              widget.readingPlanDetails.totalVerses
        : 0.0;

    final progressPercent = (progress * 100).round();
    final l10n = AppLocalizations.of(context)!;

    final Widget bookmarkWidget = ValueListenableBuilder<bool>(
      valueListenable: manager.bookmarkNotifier,
      builder: (_, isBookmarked, child) {
        return IconButton(
          icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () {
            manager.markToggleReadingPlanBookmark();
          },
        );
      },
    );

    return ValueListenableBuilder<Reference?>(
      valueListenable: manager.resumePositionNotifier,
      builder: (context, resumePosition, _) {
        final Widget progressWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.booksReadOfTotal(
                widget.readingPlanDetails.booksRead,
                widget.readingPlanDetails.books.length,
              ),
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
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                ),
                Text(
                  "$progressPercent%",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(child: progressWidget),
            bookmarkWidget,
          ],
        );
      },
    );
  }

  Widget _startResumeButton() {
    final l10n = AppLocalizations.of(context)!;

    final txt = widget.readingPlanDetails.versesRead == 0
        ? l10n.startReading
        : l10n.resumeReading;

    return ValueListenableBuilder<Reference?>(
      valueListenable: manager.resumePositionNotifier,
      builder: (_, resumePosition, child) {
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
              await manager.startReadingSession();

              if (!mounted) return;

              int bookId, chapter, verse;

              if (resumePosition != null) {
                bookId = resumePosition.bookId;
                chapter = resumePosition.chapter;
                verse = resumePosition.verse;
              } else if (_books.isNotEmpty) {
                bookId = _books[0].bookId;
                chapter = 1;
                verse = 1;
              } else {
                bookId = 1;
                chapter = 1;
                verse = 1;
              }

              widget.homeManager.onBookSelected(context, bookId);

              widget.homeManager.onChapterSelected(chapter);

              widget.homeManager.syncController.jumpToVerse(
                bookId,
                chapter,
                verse,
              );

              widget.onClose();
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(txt),
          ),
        );
      },
    );
  }

  Widget _statsRow() {
    final l10n = AppLocalizations.of(context)!;

    final goalType = widget.readingPlanDetails.dailyGoal.type;

    String goalTxt = goalType == GoalType.minutes
        ? l10n.minutesPerDay.toLowerCase()
        : l10n.versesPerDay.toLowerCase();

    final target = widget.readingPlanDetails.readingPlan.goalValue;

    final todaysProgress = ValueListenableBuilder<DayProgress?>(
      valueListenable: manager.todaysProgressNotifier,
      builder: (_, progress, child) {
        String progressStr;
        double progressValue = 0;

        if (progress == null) {
          progressStr = '0/$target';
        } else if (goalType == GoalType.verses) {
          progressValue = progress.verses / target;
          progressStr = '${progress.verses}/$target';
        } else {
          progressValue = progress.minutes / target;
          progressStr = '${progress.minutes}/$target';
        }

        return Column(
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
            if (progressValue >= 1) Text(l10n.completedToday),
          ],
        );
      },
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

  /// Computes {days, months, date} remaining to finish the plan, assuming
  /// the reader keeps hitting their daily goal. Returns null once the plan
  /// is complete or if there's no usable goal to project from.
  ({int days, double months, DateTime date})? _estimatedCompletion() {
    final totalVerses = widget.readingPlanDetails.totalVerses;
    final versesRead = widget.readingPlanDetails.versesRead;
    final remainingVerses = totalVerses - versesRead;

    if (remainingVerses <= 0) return null;

    final goalType = widget.readingPlanDetails.dailyGoal.type;
    final target = widget.readingPlanDetails.dailyGoal.value;

    if (target <= 0) return null;

    final versesPerDay = goalType == GoalType.verses
        ? target.toDouble()
        : target * _estimatedVersesPerMinute;

    if (versesPerDay <= 0) return null;

    final days = (remainingVerses / versesPerDay).ceil();
    final months = days / 30.44; // average Gregorian month length
    final date = DateTime.now().add(Duration(days: days));

    return (days: days, months: months, date: date);
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    return '${l10n.months(date.month.toString())} ${date.day}, ${date.year}';
  }

  Widget _estimatedCompletionContent() {
    final l10n = AppLocalizations.of(context)!;
    final estimate = _estimatedCompletion();

    if (estimate == null) {
      return Text(l10n.planComplete, style: const TextStyle(fontSize: 16));
    }

    return Column(
      children: [
        Text(
          l10n.daysCount(estimate.days),
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(l10n.monthsCount(estimate.months.toStringAsFixed(1))),
        const SizedBox(height: 4),
        Text(_formatDate(estimate.date)),
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
          onTap: _toggleReorderMode,
          child: Text(
            _reorderMode
                ? AppLocalizations.of(context)!.done
                : AppLocalizations.of(context)!.editOrder,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  void _toggleReorderMode() async {
    final wasReorder = _reorderMode;
    setState(() {
      _reorderMode = !_reorderMode;
    });

    // Persist the new order once the user finishes reordering.
    if (wasReorder) {
      await manager.reorderBooks(_books);
      if (mounted) setState(() {});
    }
  }

  Widget _booksList() {
    return ValueListenableBuilder<List<RsBookStats>>(
      valueListenable: manager.booksProgressNotifier,
      builder: (_, booksProgress, child) {
        if (booksProgress.isEmpty) {
          return const SizedBox.shrink();
        }

        if (_reorderMode) {
          return ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _books.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final book = _books.removeAt(oldIndex);
                _books.insert(newIndex, book);
              });
            },
            itemBuilder: (context, index) {
              final book = _books[index];
              int bookChap = _bibleNavigation.getChapterCount(book.bookId);
              int bookVerses = 0;

              for (int i = 1; i <= bookChap; i++) {
                bookVerses += _bibleNavigation.getVerseCount(book.bookId, i);
              }

              return ReorderableDragStartListener(
                key: ValueKey(book.bookId),
                index: index,
                child: _BookRow(
                  name: bookNameFromId(context, book.bookId),
                  progress:
                      booksProgress[book.bookId - 1].versesRead / bookVerses,
                  reorderable: true,
                ),
              );
            },
          );
        }

        return Column(
          children: _books.map((book) {
            int bookChap = _bibleNavigation.getChapterCount(book.bookId);
            int bookVerses = 0;

            for (int i = 1; i <= bookChap; i++) {
              bookVerses += _bibleNavigation.getVerseCount(book.bookId, i);
            }

            return _BookRow(
              name: bookNameFromId(context, book.bookId),
              progress: booksProgress[book.bookId - 1].versesRead / bookVerses,
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _openDetailedProgress(DayProgress progress) async {
    if (progress.empty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => DetailedProgressPanel(
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
      value: manager.monthProgress,
      onTap: _openDetailedProgress,
      isHighlighted: isHighlighted,
      onMonthChanged: (month) => manager.loadMonthData(month),
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
