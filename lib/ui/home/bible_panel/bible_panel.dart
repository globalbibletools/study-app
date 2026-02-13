import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/common/infinite_scroll_view.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';
import 'package:studyapp/ui/home/common/zoom_wrapper.dart';
import 'bible_chapter.dart';
import 'bible_panel_manager.dart';

class BiblePanel extends StatefulWidget {
  const BiblePanel({
    super.key,
    required this.bookId,
    required this.chapter,
    this.syncController,
  });

  final int bookId;
  final int chapter;
  final ScrollSyncController? syncController;

  @override
  State<BiblePanel> createState() => BiblePanelState();
}

class BiblePanelState extends State<BiblePanel> {
  final _manager = BiblePanelManager();

  /// Re-reads the font scale from persisted settings into the notifier.
  void refreshFromSettings() {
    _manager.refreshFromSettings();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _manager.fontScaleNotifier,
      builder: (context, currentScale, child) {
        return ZoomWrapper(
          initialScale: currentScale,
          onScaleChanged: (newScale) => _manager.saveFontScale(newScale),
          builder: (context, scale) {
            final fontSize = _manager.baseFontSize * scale;
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: InfiniteScrollView(
                bookId: widget.bookId,
                chapter: widget.chapter,
                syncController: widget.syncController,
                chapterBuilder: (context, bId, ch) {
                  return BibleChapter(
                    key: ValueKey('bible-$bId-$ch'),
                    bookId: bId,
                    chapter: ch,
                    fontSize: fontSize,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
