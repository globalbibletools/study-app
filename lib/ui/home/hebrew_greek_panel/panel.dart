import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/common/infinite_scripture_scroll_view.dart';
import 'package:studyapp/ui/home/common/zoom_wrapper.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel_manager.dart';

/// Handles infinite scrolling and zooming for multiple chapters, all contained
/// within a panel. This panel is meant to be separate but adjacent to a
/// Bible translation panel that shows English text (or another language).
class HebrewGreekPanel extends StatefulWidget {
  const HebrewGreekPanel({
    super.key,
    required this.bookId,
    required this.chapter,
  });

  final int bookId;
  final int chapter;

  @override
  State<HebrewGreekPanel> createState() => _HebrewGreekPanelState();
}

class _HebrewGreekPanelState extends State<HebrewGreekPanel> {
  final _manager = HebrewGreekPanelManager();

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

            return InfiniteScriptureScrollView(
              bookId: widget.bookId,
              chapter: widget.chapter,
              chapterBuilder: (context, bId, ch) {
                return HebrewGreekChapter(
                  key: ValueKey('page-$bId-$ch'),
                  bookId: bId,
                  chapter: ch,
                  fontSize: fontSize,
                );
              },
            );
          },
        );
      },
    );
  }
}
