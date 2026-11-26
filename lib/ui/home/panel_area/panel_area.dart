import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/reading_plan/ui/book_completed_overlay.dart';
import 'package:gbt/reading_plan/ui/goal_reached_overlay.dart';
import 'package:gbt/reading_plan/ui/reading_session_hud.dart';
import 'package:gbt/ui/home/panel_area/bible_panel/bible_panel.dart';
import 'package:gbt/ui/home/panel_area/hebrew_greek_panel/chapter.dart';
import 'package:gbt/ui/home/panel_area/hebrew_greek_panel/panel.dart';
import 'package:gbt/ui/home/home_manager.dart';

class BiblePanelArea extends StatelessWidget {
  const BiblePanelArea({super.key, required this.manager});

  final HomeManager manager;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<VerseNumberTapNotification>(
      onNotification: (notification) {
        final isShowingPlayer = manager.audioPlayerViewModel.isVisible;
        if (isShowingPlayer) {
          manager.audioPlayerViewModel
              .jumpTo(
                Reference(
                  bookId: notification.bookId,
                  chapter: notification.chapter,
                  verse: notification.verse,
                ),
              )
              .then((_) => manager.audioPlayerViewModel.play());
        }
        return true;
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          manager.navigationViewModel.anchor,
          manager.isSinglePanelNotifier,
          manager.settingsVersionNotifier,
          manager.readingSessionViewModel,
          manager.appGuideManager.readingCheckboxGuideDismissedNotifier,
          manager.appGuideManager.readingSessionGuideDismissedNotifier,
        ]),
        builder: (context, _) {
          final anchor = manager.navigationViewModel.anchor.value;
          final isSinglePanel = manager.isSinglePanelNotifier.value;
          final settingsVersion = manager.settingsVersionNotifier.value;
          final shouldOffsetForProgress =
              manager.readingSessionViewModel.hasActiveSession &&
              manager.readingSessionViewModel.hudVisible;

          final shouldShowReadingCheckboxGuide =
              manager.appGuideManager.shouldShowReadingCheckboxGuide;

          final disableScrolling = manager.appGuideManager.anyGuideShown();

          final content = AnimatedPadding(
            duration: Duration(
              milliseconds: shouldShowReadingCheckboxGuide ? 0 : 220,
            ),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(top: shouldOffsetForProgress ? 44 : 0),
            child: Column(
              children: [
                // Top Panel (Hebrew/Greek)
                Expanded(
                  child: HebrewGreekPanel(
                    key: ValueKey('hg-${anchor.bookId}-${anchor.chapter}'),
                    bookId: anchor.bookId,
                    chapter: anchor.chapter,
                    highlightNotifier: manager.audioPlayerViewModel.reference,
                    settingsVersion: settingsVersion,
                    scrollingEnabled: !disableScrolling,
                    showReadingCheckboxGuide: shouldShowReadingCheckboxGuide,
                    onReadingCheckboxGuideRectChanged: (value) {
                      manager.appGuideManager.checkBoxSpotlightRect.value =
                          value;
                    },
                    onReadingCheckboxGuideCompleted:
                        manager.appGuideManager.dismissReadingCheckboxGuide,
                  ),
                ),

                // Bottom Panel (Bible Translation)
                if (!isSinglePanel) ...[
                  const Divider(height: 0, indent: 8, endIndent: 8),
                  Expanded(
                    child: BiblePanel(
                      key: ValueKey('bi-${anchor.bookId}-${anchor.chapter}'),
                      bookId: anchor.bookId,
                      chapter: anchor.chapter,
                      settingsVersion: settingsVersion,
                      scrollingEnabled: !disableScrolling,
                      onResourceUnavailable: manager.closeBiblePanel,
                    ),
                  ),
                ],
              ],
            ),
          );

          return Stack(
            children: [
              content,
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: ReadingSessionHud(
                  viewModel: manager.readingSessionViewModel,
                ),
              ),

              if (manager.readingSessionViewModel.hasActiveSession) ...[
                GoalReachedOverlay(viewModel: manager.readingSessionViewModel),
                BookCompletedOverlay(
                  viewModel: manager.readingSessionViewModel,
                  onNextBook: (bookId) => onNextBook(context, bookId),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void onNextBook(BuildContext context, int _) {
    final resume = manager.readingSessionViewModel.nextResumePosition;
    if (resume == null) return;

    manager.navigationViewModel.navigateTo(resume);
  }
}
