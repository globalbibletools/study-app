import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/common/infinite_scroll_view.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';
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
    this.syncController,
  });

  final int bookId;
  final int chapter;
  final ScrollSyncController? syncController;

  @override
  State<HebrewGreekPanel> createState() => _HebrewGreekPanelState();
}

class _HebrewGreekPanelState extends State<HebrewGreekPanel> {
  final _manager = HebrewGreekPanelManager();
  late int _activeBookId;

  @override
  void initState() {
    super.initState();
    _activeBookId = widget.bookId;
    _manager.currentBookId = _activeBookId;
  }

  @override
  void didUpdateWidget(covariant HebrewGreekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId) {
      _activeBookId = widget.bookId;
      _manager.currentBookId = _activeBookId;
    }
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  void _onVisibleBookChanged(int bookId) {
    // Update the manager immediately so pinch-to-zoom saves to the right
    // language, but do NOT call setState. Rebuilding the tree while the user
    // is scrolling would change ZoomWrapper.initialScale, causing a visual
    // scale jump and scroll-position disruption at the Hebrew/Greek boundary.
    // The per-chapter fontSize is already correct because each chapter picks
    // its own scale in the chapterBuilder closure.
    _activeBookId = bookId;
    _manager.currentBookId = bookId;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _manager.hebrewScaleNotifier,
      builder: (context, hebrewScale, child) {
        return ValueListenableBuilder<double>(
          valueListenable: _manager.greekScaleNotifier,
          builder: (context, greekScale, child) {
            final isHebrew = _manager.isHebrew(_activeBookId);
            final activeScale = isHebrew ? hebrewScale : greekScale;

            return ZoomWrapper(
              initialScale: activeScale,
              onScaleChanged: (newScale) => _manager.handleZoom(newScale),
              builder: (context, scale) {
                return InfiniteScrollView(
                  bookId: widget.bookId,
                  chapter: widget.chapter,
                  syncController: widget.syncController,
                  onVisibleBookChanged: _onVisibleBookChanged,
                  chapterBuilder: (context, bookId, chapter) {
                    final chapterIsHebrew = _manager.isHebrew(bookId);
                    final chapterScale = chapterIsHebrew
                        ? hebrewScale
                        : greekScale;
                    final fontSize = _manager.baseFontSize * chapterScale;
                    return HebrewGreekChapter(
                      key: ValueKey('page-$bookId-$chapter'),
                      bookId: bookId,
                      chapter: chapter,
                      fontSize: fontSize,
                      syncController: widget.syncController,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
