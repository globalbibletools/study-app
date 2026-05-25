import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/reading_session/rs_model.dart';
import 'package:studyapp/ui/home/common/cutout_view.dart';
import 'package:studyapp/ui/home/common/glowing_button.dart';
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
  final _goalButtonKey = GlobalKey();

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
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ValueListenableBuilder<MainTab>(
      valueListenable: manager.selectedMainTab,
      builder: (context, selectedTab, _) {
        return CutoutView(
          enabled:
              selectedTab == MainTab.goals &&
              manager.dailyGoalNotifier.value == null,
          objects: [
            SpotlightObject.fromKey(
              key: _goalButtonKey,
              inflate: 3,
              radius: 28,
            ),
          ],
          content: Container(
            height: screenHeight * 0.85,
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
                  text.toUpperCase(),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    return Column(
      children: [
        _subTabsProgress(),
        const SizedBox(height: 16),
        Expanded(child: _progressTabContent()),
        const SizedBox(height: 20),
        _startButtonOrNone(),
      ],
    );
  }

  Widget goalsTabContent() {
    return Column(
      children: [
        _subTabsGoals(),
        const SizedBox(height: 10),
        _dailyGoalText(),
        Expanded(child: _goalsTabContent()),
        const SizedBox(height: 5),
        _legend(),
        const SizedBox(height: 10),
        _totals(),
        _changeGoalButton(),
        _startButtonOrNone(),
      ],
    );
  }

  Widget _progressTabContent() {
    return ValueListenableBuilder(
      valueListenable: manager.selectedPTabNotifier,
      builder: (context, value, _) {
        switch (value) {
          case ProgressTab.byBook:
            return _progressByBookTabContent();
          case ProgressTab.bySection:
            return _progressBySectionTabContent();
        }
      },
    );
  }

  int _compareProgress(RsBookProgress a, RsBookProgress b) {
    if (b.id == null && a.id != null) {
      return -1;
    }
    if (a.id == null && b.id != null) {
      return 1;
    }
    if (a.id == null && b.id == null) {
      return a.bookId.compareTo(b.bookId);
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  Widget _progressBySectionTabContent() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<List<RsBookProgress>>(
      valueListenable: manager.booksProgressNotifier,
      builder: (context, booksProgress, _) {
        final newTestamentStartBookId = BibleNavigation.getNewTestamentBookId();
        final oldTestamentProgressList =
            booksProgress
                .where((b) => b.bookId < newTestamentStartBookId)
                .toList()
              ..sort(_compareProgress);

        final newTestamentProgressList =
            booksProgress
                .where((b) => b.bookId >= newTestamentStartBookId)
                .toList()
              ..sort(_compareProgress);

        // Latest items
        final latestOldTestament = oldTestamentProgressList.isNotEmpty
            ? oldTestamentProgressList.first
            : RsBookProgress(
                bookId: 1,
                chapter: 1,
                verse: 1,
                chaptersRead: 0,
                versesRead: 0,
                updatedAt: DateTime.now(),
              );

        final latestNewTestament = newTestamentProgressList.isNotEmpty
            ? newTestamentProgressList.first
            : RsBookProgress(
                bookId: newTestamentStartBookId,
                chapter: 1,
                verse: 1,
                chaptersRead: 0,
                versesRead: 0,
                updatedAt: DateTime.now(),
              );
        //Books read
        var oldTestamentBooksRead = 0;
        var newTestamentBooksRead = 0;
        var totalOldTestament = newTestamentStartBookId - 1;
        var totalNewTestament =
            BibleNavigation.getBooksCount() - newTestamentStartBookId + 1;

        for (RsBookProgress progress in booksProgress) {
          if (progress.chaptersRead !=
              BibleNavigation.getChapterCount(progress.bookId)) {
            continue;
          } else if (progress.bookId < newTestamentStartBookId) {
            oldTestamentBooksRead += 1;
          } else {
            newTestamentBooksRead += 1;
          }
        }

        return ListView(
          children: [
            _bookCard(
              latestOldTestament,
              l10n.oldTestament,
              oldTestamentBooksRead / totalOldTestament,
              "$oldTestamentBooksRead/$totalOldTestament",
              "",
              latestOldTestament.id == null ? l10n.start : l10n.resume,
            ),

            _bookCard(
              latestNewTestament,
              l10n.newTestament,
              newTestamentBooksRead / totalNewTestament,
              "$newTestamentBooksRead/$totalNewTestament",
              "",
              latestNewTestament.id == null ? l10n.start : l10n.resume,
            ),
          ],
        );
      },
    );
  }

  Widget _progressByBookTabContent() {
    final content = ValueListenableBuilder<BookProgressTab>(
      valueListenable: manager.selectedBPTabNotifier,
      builder: (context, value, _) {
        late final List<int> books;
        switch (value) {
          case BookProgressTab.christian:
            books = BibleNavigation.christianBooks;
            break;
          case BookProgressTab.jewish:
            books = BibleNavigation.jewishBooks;
            break;
          case BookProgressTab.easyToHard:
            books = BibleNavigation.easyToHardest;
            break;
        }
        return _booksFromList(books);
      },
    );
    return Column(
      children: [
        _subBookTabsProgress(),
        Expanded(child: content),
      ],
    );
  }

  Widget _booksFromList(List<int> books) {
    return ValueListenableBuilder<List<RsBookProgress>>(
      valueListenable: manager.booksProgressNotifier,
      builder: (context, booksProgress, _) {
        return ListView(
          children: books.map((bookId) {
            return _bookTitle(booksProgress[bookId - 1]);
          }).toList(),
        );
      },
    );
  }

  Widget _bookTitle(RsBookProgress book) {
    final l10n = AppLocalizations.of(context)!;

    final action = book.id == null ? l10n.start : l10n.resume;
    final bookName = bookNameFromId(context, book.bookId);
    final totalChapters = BibleNavigation.getChapterCount(book.bookId);

    int versesCount = 0;
    for (int i = 1; i <= totalChapters; i++) {
      versesCount += BibleNavigation.getVerseCount(book.bookId, i);
    }

    return _bookCard(
      book,
      bookName,
      book.versesRead / versesCount,
      "${book.versesRead}/$versesCount",
      "${l10n.versesShort}. ".toUpperCase(),
      action,
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
            childAspectRatio: 1,
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
        _tab(l10n.byBook, manager.selectedPTabNotifier, ProgressTab.byBook),
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

  Widget _subBookTabsProgress() {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _tab(
          l10n.christianOrder,
          manager.selectedBPTabNotifier,
          BookProgressTab.christian,
        ),
        const SizedBox(width: 8),
        _tab(
          l10n.jewishOrder,
          manager.selectedBPTabNotifier,
          BookProgressTab.jewish,
        ),
        const SizedBox(width: 8),
        _tab(
          l10n.easyToHardOrder,
          manager.selectedBPTabNotifier,
          BookProgressTab.easyToHard,
        ),
      ],
    );
  }

  Widget _bookCard(
    RsBookProgress bookProgress,
    String title,
    double progress,
    String progressLabel,
    String progressPrefix,
    String action,
  ) {
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
                      "$progressPrefix$progressLabel",
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

  Widget _startButtonOrNone() {
    return ValueListenableBuilder(
      valueListenable: manager.dailyGoalNotifier,
      builder: (_, dailyGoal, child) {
        if (dailyGoal == null) {
          return const SizedBox.shrink();
        } else {
          return _startButton();
        }
      },
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
          final child = Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
                      l10n.startSession.toUpperCase(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.whereYouLeftOff, style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(width: double.infinity, child: child),
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
                          ? Icon(Icons.check, color: color, size: 18)
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
    final color = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetailedProgress(progress),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: progress.goalReached
                ? color
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: isToday ? Border.all(color: color, width: 2) : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Text(
                  "${progress.day.day}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: progress.goalReached
                        ? Colors.white.withValues(alpha: 0.9)
                        : null,
                  ),
                ),
              ),

              if (progress.goalReached)
                const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 42,
                    weight: 700,
                  ),
                ),
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
        if (value == null) {
          return Center(
            child: Text(
              l10n.dailyGoalNotSet,
              style: TextStyle(color: color, fontSize: 16),
            ),
          );
        }

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
            Icon(Icons.check, color: color, size: 16),
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final currentGoal = manager.dailyGoalNotifier.value;

    return Center(
      child: KeyedSubtree(
        child: GlowingButton(
          duration: 3000,
          primaryColor: colorScheme.primary,
          borderRadius: 28,
          glowInset: 10,
          strokeWidth: 3,
          child: ElevatedButton.icon(
            key: _goalButtonKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () async {
              final result = await showModalBottomSheet<(GoalType, int)>(
                context: context,
                isScrollControlled: true,
                isDismissible: true,
                backgroundColor: Colors.transparent,
                builder: (_) => SetDailyGoalView(
                  initialGoalType: currentGoal?.type,
                  initialValue: currentGoal?.value,
                ),
              );

              if (result != null) {
                manager.updateGoal(result.$1, result.$2);
              }

              setState(() {});
            },
            label: ValueListenableBuilder(
              valueListenable: manager.dailyGoalNotifier,
              builder: (_, dailyGoal, child) {
                return Text(
                  dailyGoal == null
                      ? l10n.setGoal.toUpperCase()
                      : l10n.changeGoal.toUpperCase(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
