import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';
import 'package:studyapp/ui/home/home_manager.dart';
import 'package:studyapp/ui/home/reading_session/daily_goal_panel.dart';
import 'package:studyapp/ui/home/reading_session/detailed_progress_panel.dart';
import 'package:studyapp/ui/home/reading_session/reading_session_panel_manager.dart';

class ReadingSessionPanel extends StatefulWidget {
  final HomeManager homeManager;
  final ReadingSessionManager readingSessionManager;

  ReadingSessionPanel({super.key, required this.homeManager})
    : readingSessionManager = homeManager.readingSessionManager;

  @override
  State<ReadingSessionPanel> createState() => ReadingSessionPanelState();
}

class ReadingSessionPanelState extends State<ReadingSessionPanel> {
  late final ReadingSessionPanelManager manager;
  @override
  void initState() {
    super.initState();
    widget.readingSessionManager.init();
    manager = ReadingSessionPanelManager();
  }

  /// Re-reads the font scale from persisted settings into the notifier.
  void refreshFromSettings() {}

  @override
  void didUpdateWidget(covariant ReadingSessionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    manager.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 16),

          _topTabs(),
          const SizedBox(height: 12),

          Flexible(child: _content()),
        ],
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

  Widget _tab<T>(String text, ValueNotifier<T> notifierValue, T value) {
    return ValueListenableBuilder<T>(
      valueListenable: notifierValue,
      builder: (context, v, _) {
        final active = v == value;
        return Expanded(
          child: Material(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                notifierValue.value = value;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topTabs() {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _tab(l10n.progress, manager.selectedMainTab, MainTab.progress),
        const SizedBox(width: 8),
        _tab(l10n.goals, manager.selectedMainTab, MainTab.goals),
      ],
    );
  }

  Widget _content() {
    return ValueListenableBuilder(
      valueListenable: manager.selectedMainTab,
      builder: (context, value, _) {
        switch (value) {
          case MainTab.progress:
            return progressTabContent();
          case MainTab.goals:
            return goalsTabContent();
        }
      },
    );
  }

  Widget progressTabContent() {
    return ValueListenableBuilder<List<RsBookProgress>>(
      valueListenable: manager.booksProgressNotifier,
      builder: (context, booksProgress, _) {
        return Column(
          children: [
            _subTabsProgress(),
            const SizedBox(height: 16),
            _progressTabContent(),
            const SizedBox(height: 20),
            _startButton(),
          ],
        );
      },
    );
  }

  Widget goalsTabContent() {
    return Column(
      children: [
        _subTabsGoals(),
        const SizedBox(height: 16),
        _dailyGoalText(),
        const SizedBox(height: 20),
        Expanded(child: _goalsTabContent()),
        const SizedBox(height: 30),
        _legend(),
        const SizedBox(height: 20),
        _totals(),
        const SizedBox(height: 20),
        _changeGoalButton(),
        const SizedBox(height: 20),
        _startButton(),
      ],
    );
  }

  Widget _progressTabContent() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<List<RsBookProgress>>(
      valueListenable: manager.booksProgressNotifier,
      builder: (context, booksProgress, _) {
        return Expanded(
          child: ListView(
            children: booksProgress.map((book) {
              final action = book.id == null ? l10n.start : l10n.resume;
              final bookName = bookNameFromId(context, book.bookId);
              final totalChapters = BibleNavigation.getChapterCount(
                book.bookId,
              );

              return _bookCard(
                book,
                bookName,
                book.chaptersRead / totalChapters,
                "${book.chaptersRead}/$totalChapters",
                action,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _goalsTabContent() {
    return ValueListenableBuilder<GoalsTab>(
      valueListenable: manager.selectedGTabNotifier,
      builder: (context, value, _) {
        switch (value) {
          case GoalsTab.byWeek:
            return _goalsContentByWeek();
          case GoalsTab.byMonth:
            return _goalsContentByMonth();
        }
      },
    );
  }

  Widget _goalsContentByWeek() {
    final color = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder<List<DayProgress>>(
      valueListenable: manager.goalsDataNotifier,
      builder: (ctx, data, _) {
        return ListView(
          children: data.map((day) {
            return _dayRow(day, color);
          }).toList(),
        );
      },
    );
  }

  Widget _goalsContentByMonth() {
    return ValueListenableBuilder<List<DayProgress>>(
      valueListenable: manager.goalsDataNotifier,
      builder: (ctx, data, _) {
        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, 1);
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

        final firstWeekday = firstDay.weekday; // 1 = Mon

        final totalCells = daysInMonth + (firstWeekday - 1);

        return GridView.builder(
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.3,
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - (firstWeekday - 2);
            final date = DateTime(now.year, now.month, dayNumber);
            final progress = data[dayNumber - 1];

            final isToday = date.day == now.day;

            return _dayCalendar(progress, isToday);
          },
        );
      },
    );
  }

  Widget _subTabsProgress() {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _tab(
          l10n.bySection,
          manager.selectedPTabNotifier,
          ProgressTab.bySection,
        ),
        const SizedBox(width: 8),
        _tab(
          l10n.byBook,
          manager.selectedPTabNotifier,
          ProgressTab.byBook,
        ),
      ],
    );
  }

  Widget _subTabsGoals() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _tab(l10n.week, manager.selectedGTabNotifier, GoalsTab.byWeek),
        const SizedBox(width: 8),
        _tab(l10n.month, manager.selectedGTabNotifier, GoalsTab.byMonth),
      ],
    );
  }

  Widget _bookCard(
    RsBookProgress bookProgress,
    String title,
    double progress,
    String chapters,
    String action,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            log("starting reading session");

            await widget.readingSessionManager.startReadingSession();
            if (!mounted) return;

            widget.homeManager.onBookSelected(context, bookProgress.bookId);

            widget.homeManager.onChapterSelected(bookProgress.chapter);

            widget.homeManager.syncController.jumpToVerse(
              bookProgress.bookId,
              bookProgress.chapter,
              bookProgress.verse,
            );

            Navigator.of(context).maybePop();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 18)),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLowest,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      "${l10n.chapterShort}. $chapters",
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),

                    Text(
                      action,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton() {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<RsBookProgress?>(
      valueListenable: manager.latestBookProgressNotifier,
      builder: (_, latestBookProgress, child) {
        if (latestBookProgress == null) {
          return const SizedBox.shrink();
        } else {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Material(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  log("starting reading session");

                  await widget.readingSessionManager.startReadingSession();
                  if (!mounted) return;

                  widget.homeManager.onBookSelected(
                    context,
                    latestBookProgress.bookId,
                  );

                  widget.homeManager.onChapterSelected(
                    latestBookProgress.chapter,
                  );

                  widget.homeManager.syncController.jumpToVerse(
                    latestBookProgress.bookId,
                    latestBookProgress.chapter,
                    latestBookProgress.verse,
                  );

                  Navigator.of(context).maybePop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.startSession,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.whereYouLeftOff,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _dayRow(DayProgress d, Color color) {
    final l10n = AppLocalizations.of(context)!;
    final dayOfWeek = l10n.dayOfWeek(d.day.weekday.toString());
    final minuteLabel = l10n.minutesShort;
    final verseLabel = l10n.versesShort;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetailedProgress(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        dayOfWeek,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: d.goalReached
                          ? Icon(Icons.adjust, color: color, size: 18)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    "${d.minutes} $minuteLabel",
                    style: TextStyle(color: color, fontSize: 16),
                  ),
                ),
              ),

              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    "${d.verses} $verseLabel",
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCalendar(DayProgress progress, bool isToday) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openDetailedProgress(progress),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: progress.goalReached
                ? color
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: color, width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${progress.day.day}",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!progress.empty)
                Text(
                  "${progress.minutes}${l10n.minutesShort}|${progress.verses} ${l10n.versesShort}",
                  style: TextStyle(fontSize: 10),
                )
              else
                Text("--", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetailedProgress(DayProgress progress) async {
    if (progress.empty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => DetailedProgressPanel(date: progress.day),
    );
  }

  Widget _dailyGoalText() {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.primary;

    return ValueListenableBuilder(
      valueListenable: manager.dailyGoalNotifier,
      builder: (_, value, _) {
        final minuteLabel = l10n.minutes;
        final versesLabel = l10n.verses;

        return Center(
          child: Text(
            "${l10n.dailyGoal}: ${value.value} ${value.type == GoalType.minutes ? minuteLabel : versesLabel}",
            style: TextStyle(color: color, fontSize: 16),
          ),
        );
      },
    );
  }

  Widget _legend() {
    final color = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<GoalsTab>(
      valueListenable: manager.selectedGTabNotifier,
      builder: (context, value, child) {
        return Row(
          children: [
            value == GoalsTab.byWeek
                ? Icon(Icons.adjust, color: color, size: 16)
                : Icon(Icons.square, color: color, size: 16),
            const SizedBox(width: 8),
            Text("= ${l10n.dailyGoalReached}", style: TextStyle(color: color)),
          ],
        );
      },
    );
  }

  Widget _totals() {
    final color = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<List<DayProgress>>(
      valueListenable: manager.goalsDataNotifier,
      builder: (context, days, _) {
        final totalMinutes = days.fold<int>(0, (sum, d) => sum + d.minutes);
        final totalVerses = days.fold<int>(0, (sum, d) => sum + d.verses);

        return Center(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: "${l10n.total}: "),
                TextSpan(
                  text: "$totalMinutes ${l10n.minutesShort}",
                  style: TextStyle(color: color),
                ),
                const TextSpan(text: " • "),
                TextSpan(
                  text: "$totalVerses ${l10n.verses}",
                  style: const TextStyle(color: Colors.pinkAccent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _changeGoalButton() {
    final color = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () async {
          final currentGoal = manager.dailyGoalNotifier.value;
          final result = await showModalBottomSheet<(GoalType, int)>(
            context: context,
            isScrollControlled: true,
            isDismissible: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SetDailyGoalView(
              initialGoalType: currentGoal.type,
              initialValue: currentGoal.value,
            ),
          );

          if (result != null) {
            manager.updateGoal(result.$1, result.$2);
          }
        },
        icon: const Icon(Icons.adjust),
        label: Text(l10n.changeGoal),
      ),
    );
  }
}
