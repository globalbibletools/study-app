import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/common/infinite_scroll_view.dart';
import 'package:studyapp/ui/home/common/zoom_wrapper.dart';
import 'bible_chapter.dart';
import 'bible_panel_manager.dart';

class BiblePanel extends StatefulWidget {
  const BiblePanel({super.key, required this.bookId, required this.chapter});

  final int bookId;
  final int chapter;

  @override
  State<BiblePanel> createState() => _BiblePanelState();
}

class _BiblePanelState extends State<BiblePanel> {
  final _manager = BiblePanelManager();

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
