import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/common/cutout_view.dart';
import 'package:studyapp/ui/home/common/guide_bubble.dart';
import 'package:studyapp/ui/home/panel_area/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/panel_area/common/goal_reached_overlay.dart';
import 'package:studyapp/ui/home/panel_area/common/reading_session_overlay.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/panel.dart';
import 'package:studyapp/ui/home/home_manager.dart';

class BiblePanelArea extends StatelessWidget {
  BiblePanelArea({super.key, required this.manager});

  final HomeManager manager;
  final _panelAreaKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return NotificationListener<VerseNumberTapNotification>(
      onNotification: (notification) {
        final isShowingPlayer = manager.audioManager.isVisibleNotifier.value;
        if (isShowingPlayer) {
          manager.audioManager.play(
            checkBookId: notification.bookId,
            checkChapter: notification.chapter,
            checkBookName: bookNameFromId(context, notification.bookId),
            startVerse: notification.verse,
          );
        }
        return true;
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([
          manager.panelAnchorNotifier,
          manager.isSinglePanelNotifier,
          manager.settingsVersionNotifier,
          manager.readingSessionManager.readingModeNotifier,
          manager.readingSessionManager.displayGoalProgresNotifier,
          manager.readingSessionManager.checkBoxSpotlightRect,
          manager.readingSessionManager.readingCheckboxGuideDismissedNotifier,
        ]),
        builder: (context, _) {
          final anchor = manager.panelAnchorNotifier.value;
          final isSinglePanel = manager.isSinglePanelNotifier.value;
          final settingsVersion = manager.settingsVersionNotifier.value;
          final shouldOffsetForProgress =
              manager.readingSessionManager.readingModeNotifier.value &&
              manager.readingSessionManager.displayGoalProgresNotifier.value &&
              manager.readingSessionManager.getDailyGoal() != null;
          final shouldShowReadingCheckboxGuide =
              manager.readingSessionManager.shouldShowReadingCheckboxGuide;

          final spotlightRect = shouldShowReadingCheckboxGuide
              ? manager.readingSessionManager.checkBoxSpotlightRect.value
              : null;

          final content = AnimatedPadding(
            duration: const Duration(milliseconds: 220),
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
                    syncController: manager.syncController,
                    settingsVersion: settingsVersion,
                    scrollingEnabled: !shouldShowReadingCheckboxGuide,
                    showReadingCheckboxGuide: shouldShowReadingCheckboxGuide,
                    onReadingCheckboxGuideRectChanged: (value) {
                      manager
                              .readingSessionManager
                              .checkBoxSpotlightRect
                              .value =
                          value;
                    },
                    onReadingCheckboxGuideCompleted: manager
                        .readingSessionManager
                        .dismissReadingCheckboxGuide,
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
                      syncController: manager.syncController,
                      settingsVersion: settingsVersion,
                      scrollingEnabled: !shouldShowReadingCheckboxGuide,
                    ),
                  ),
                ],
              ],
            ),
          );

          List<SpotlightObject> objects = [];

          if (spotlightRect != null) {
            objects.add(SpotlightObject.fromGlobalRect(rect: spotlightRect));
          }

          final l10n = AppLocalizations.of(context)!;

          return Stack(
            key: _panelAreaKey,
            children: [
              CutoutView(
                content: content,
                objects: objects,
                enabled: objects.isNotEmpty,
              ),

              if (spotlightRect != null)
                GuideBubble(
                  targetGlobalRect: spotlightRect,
                  panelAreaKey: _panelAreaKey,
                  onDismiss:
                      manager.readingSessionManager.dismissReadingCheckboxGuide,
                  title: l10n.readingCheckboxGuideTitle,
                  text: l10n.readingCheckboxGuideMessage,
                  dismissText: l10n.gotIt,
                ),

              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: ReadingSessionOverlay(
                  manager: manager.readingSessionManager,
                ),
              ),

              GoalReachedOverlay(manager: manager.readingSessionManager),
            ],
          );
        },
      ),
    );
  }
}
