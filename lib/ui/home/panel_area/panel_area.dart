import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/panel_area/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/panel.dart';
import 'package:studyapp/ui/home/home_manager.dart';
import 'package:studyapp/common/reference.dart';

class BiblePanelArea extends StatelessWidget {
  const BiblePanelArea({super.key, required this.manager});

  final HomeManager manager;

  @override
  Widget build(BuildContext context) {
    // 1. Listen for "Hard Jumps"
    return ValueListenableBuilder<Reference>(
      valueListenable: manager.panelAnchorNotifier,
      builder: (context, anchor, _) {
        // 2. Listen for Single/Dual Panel toggles
        return ValueListenableBuilder<bool>(
          valueListenable: manager.isSinglePanelNotifier,
          builder: (context, isSinglePanel, _) {
            // 3. NEW: Listen for Settings Updates
            return ValueListenableBuilder<int>(
              valueListenable: manager.settingsVersionNotifier,
              builder: (context, settingsVersion, _) {
                return Listener(
                  onPointerDown: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: NotificationListener<VerseNumberTapNotification>(
                    onNotification: (notification) {
                      if (manager.audioManager.isVisibleNotifier.value) {
                        manager.audioManager.play(
                          checkBookId: notification.bookId,
                          checkChapter: notification.chapter,
                          checkBookName: bookNameFromId(
                            context,
                            notification.bookId,
                          ),
                          startVerse: notification.verse,
                        );
                      }
                      return true;
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: HebrewGreekPanel(
                            key: ValueKey(
                              'hg-${anchor.bookId}-${anchor.chapter}',
                            ),
                            bookId: anchor.bookId,
                            chapter: anchor.chapter,
                            syncController: manager.syncController,
                            settingsVersion: settingsVersion,
                          ),
                        ),
                        if (!isSinglePanel) ...[
                          const Divider(height: 0, indent: 8, endIndent: 8),
                          Expanded(
                            child: BiblePanel(
                              key: ValueKey(
                                'bi-${anchor.bookId}-${anchor.chapter}',
                              ),
                              bookId: anchor.bookId,
                              chapter: anchor.chapter,
                              syncController: manager.syncController,
                              settingsVersion: settingsVersion,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
