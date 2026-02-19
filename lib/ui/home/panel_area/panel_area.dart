import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/panel_area/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/panel.dart';
import 'package:studyapp/ui/home/home_manager.dart';

class BiblePanelArea extends StatelessWidget {
  const BiblePanelArea({super.key, required this.manager});

  final HomeManager manager;

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
        ]),
        builder: (context, _) {
          final anchor = manager.panelAnchorNotifier.value;
          final isSinglePanel = manager.isSinglePanelNotifier.value;
          final settingsVersion = manager.settingsVersionNotifier.value;

          return Column(
            children: [
              // Top Panel (Hebrew/Greek)
              Expanded(
                child: HebrewGreekPanel(
                  key: ValueKey('hg-${anchor.bookId}-${anchor.chapter}'),
                  bookId: anchor.bookId,
                  chapter: anchor.chapter,
                  syncController: manager.syncController,
                  settingsVersion: settingsVersion,
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
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
