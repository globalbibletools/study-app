import 'package:flutter/material.dart';
import 'package:studyapp/services/settings/user_settings.dart';
import 'package:studyapp/ui/home/panel_area/common/infinite_scroll_view.dart';
import 'package:studyapp/ui/home/common/scroll_sync_controller.dart';
import 'package:studyapp/ui/home/common/zoom_wrapper.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/panel_area/hebrew_greek_panel/panel_manager.dart';

class HebrewGreekPanel extends StatefulWidget {
  const HebrewGreekPanel({
    super.key,
    required this.bookId,
    required this.chapter,
    this.syncController,
    required this.settingsVersion,
  });

  final int bookId;
  final int chapter;
  final ScrollSyncController? syncController;
  final int settingsVersion;

  @override
  State<HebrewGreekPanel> createState() => HebrewGreekPanelState();
}

class HebrewGreekPanelState extends State<HebrewGreekPanel> {
  final _manager = HebrewGreekPanelManager();
  late int _activeBookId;
  int _lockedZoomBookId = 1;
  final GlobalKey<InfiniteScrollViewState> _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _activeBookId = widget.bookId;
    _lockedZoomBookId = widget.bookId;
    _manager.currentBookId = _activeBookId;
  }

  @override
  void didUpdateWidget(covariant HebrewGreekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId) {
      _activeBookId = widget.bookId;
      _manager.currentBookId = _activeBookId;
    }
    if (widget.settingsVersion != oldWidget.settingsVersion) {
      refreshFromSettings();
    }
  }

  void refreshFromSettings() {
    _manager.refreshFromSettings();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  void _onVisibleBookChanged(int bookId) {
    _activeBookId = bookId;
    _manager.currentBookId = bookId;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _manager.readingModeEnabledNotifier,
      builder: (context, readingModeEnabled, child) {
        return ValueListenableBuilder<VerseLayout>(
          valueListenable: _manager.verseLayoutNotifier,
          builder: (context, verseLayout, child) {
            return ValueListenableBuilder<double>(
              valueListenable: _manager.hebrewScaleNotifier,
              builder: (context, hebrewScale, child) {
                return ValueListenableBuilder<double>(
                  valueListenable: _manager.greekScaleNotifier,
                  builder: (context, greekScale, child) {
                    return ZoomWrapper(
                      initialScale: _manager.isHebrew(_activeBookId)
                          ? hebrewScale
                          : greekScale,
                      getInitialScale: () =>
                          _manager.isHebrew(_lockedZoomBookId)
                          ? hebrewScale
                          : greekScale,
                      onZoomStart: (focalPoint) {
                        final touchedBookId = _scrollKey.currentState
                            ?.getBookIdAtViewportOffset(focalPoint.dy);
                        if (touchedBookId != null) {
                          _lockedZoomBookId = touchedBookId;
                        } else {
                          _lockedZoomBookId = _activeBookId;
                        }
                      },
                      onScaleChanged: (newScale) => _manager.handleZoomForBook(
                        _lockedZoomBookId,
                        newScale,
                      ),
                      builder: (context, scale) {
                        return InfiniteScrollView(
                          key: _scrollKey,
                          bookId: widget.bookId,
                          chapter: widget.chapter,
                          syncController: widget.syncController,
                          onVisibleBookChanged: _onVisibleBookChanged,
                          chapterBuilder: (context, bookId, chapter) {
                            final chapterIsHebrew = _manager.isHebrew(bookId);
                            final chapterScale = chapterIsHebrew
                                ? hebrewScale
                                : greekScale;
                            final fontSize =
                                _manager.baseFontSize * chapterScale;
                            return HebrewGreekChapter(
                              key: ValueKey('page-$bookId-$chapter'),
                              bookId: bookId,
                              chapter: chapter,
                              fontSize: fontSize,
                              syncController: widget.syncController,
                              verseLayout: verseLayout,
                              readingModeEnabled: readingModeEnabled,
                            );
                          },
                        );
                      },
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
