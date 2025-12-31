import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/common/chapter_count.dart';
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
  late final ScrollController _scrollController;
  final List<ChapterIdentifier> _displayedChapters = [];
  late ChapterIdentifier _centerChapter;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  final Map<ChapterIdentifier, GlobalKey> _chapterKeys = {};

  late final double _baseFontSize;

  // The scale at the end of the last zoom gesture.
  late double _baseScale;

  // The current scale during a zoom gesture.
  late double _currentScale;

  // The scale at the beginning of the current zoom gesture.
  double _gestureStartScale = 1.0;

  // The alignment for the Transform.scale, calculated from the gesture's focal point.
  Alignment _transformAlignment = Alignment.center;

  // Computed font size based on the last committed scale.
  double get _fontSize => _baseFontSize * _baseScale;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);

    _baseFontSize = _manager.baseFontSize;
    _baseScale = _manager.fontScaleNotifier.value;
    _currentScale = _manager.fontScaleNotifier.value;

    _manager.fontScaleNotifier.addListener(_onFontScaleChanged);

    _resetChapters();
  }

  void _onFontScaleChanged() {
    if (mounted) {
      final newScale = _manager.fontScaleNotifier.value;
      setState(() {
        _baseScale = newScale;
        _currentScale = newScale;
      });
    }
  }

  void _resetChapters() {
    setState(() {
      _centerChapter = ChapterIdentifier(widget.bookId, widget.chapter);
      _displayedChapters.clear();
      _chapterKeys.clear();

      final previousChapter = BibleNavigation.getPreviousChapter(
        _centerChapter,
      );
      if (previousChapter != null) {
        _displayedChapters.add(previousChapter);
      }
      _displayedChapters.add(_centerChapter);
    });
  }

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(),
            (ScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  _gestureStartScale = _baseScale;
                  // Set the focal point for the zoom.
                  _updateTransformAlignment(details.localFocalPoint);
                }
                ..onUpdate = (details) {
                  setState(() {
                    // Update the current scale during the gesture.
                    _currentScale = (_gestureStartScale * details.scale).clamp(
                      0.5,
                      3.0,
                    );
                  });
                }
                ..onEnd = (details) {
                  setState(() {
                    // When the gesture ends, commit the new scale.
                    _baseScale = _currentScale;
                  });
                  // Save the new scale factor.
                  _manager.saveFontScale(_baseScale);
                };
            },
          ),
    };
  }

  void _updateTransformAlignment(Offset localFocalPoint) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    setState(() {
      _transformAlignment = _calculateAlignment(
        renderBox.size,
        localFocalPoint,
      );
    });
  }

  Alignment _calculateAlignment(Size widgetSize, Offset focalPoint) {
    final dx = focalPoint.dx.clamp(0.0, widgetSize.width);
    final dy = focalPoint.dy.clamp(0.0, widgetSize.height);
    return Alignment(
      (dx / widgetSize.width) * 2 - 1,
      (dy / widgetSize.height) * 2 - 1,
    );
  }

  @override
  void didUpdateWidget(covariant HebrewGreekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent widget rebuilds with a new book/chapter, reset the view.
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _resetChapters();
    }
  }

  void _scrollListener() {
    // Load the next chapter when scrolling near the bottom.
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadNextChapter();
    }
    // Load the previous chapter when scrolling near the top.
    if (_scrollController.position.pixels <
        _scrollController.position.minScrollExtent + 400) {
      _loadPreviousChapter();
    }
  }

  void _loadNextChapter() async {
    if (_isLoadingNextChapter || _displayedChapters.isEmpty) return;

    _isLoadingNextChapter = true;
    final lastChapter = _displayedChapters.last;
    final nextChapter = BibleNavigation.getNextChapter(lastChapter);

    if (nextChapter != null && mounted) {
      setState(() {
        _displayedChapters.add(nextChapter);
      });
    }
    // Give a small delay before allowing another load.
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingNextChapter = false;
  }

  void _loadPreviousChapter() async {
    if (_isLoadingPreviousChapter || _displayedChapters.isEmpty) return;

    _isLoadingPreviousChapter = true;
    final firstChapter = _displayedChapters.first;
    final previousChapter = BibleNavigation.getPreviousChapter(firstChapter);

    if (previousChapter != null && mounted) {
      setState(() {
        // Keep track of the current scroll offset.
        // When we add a new item at the top, the scroll position jumps.
        // We will restore it after the frame is rendered.
        final currentOffset = _scrollController.offset;
        final newKey = GlobalKey();
        _chapterKeys[previousChapter] = newKey;

        _displayedChapters.insert(0, previousChapter);

        // After the new item is added and the frame is rendered,
        // adjust the scroll position to keep the view stable.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = newKey.currentContext;
          if (context != null) {
            final renderSliver = context.findRenderObject() as RenderSliver;
            final height = renderSliver.geometry?.scrollExtent ?? 0.0;
            _scrollController.jumpTo(currentOffset + height);
          }
        });
      });
    }

    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingPreviousChapter = false;
  }

  // ChapterIdentifier? _getPreviousChapter(ChapterIdentifier current) {
  //   // Case 1: Not the first chapter of the book.
  //   if (current.chapter > 1) {
  //     return ChapterIdentifier(current.bookId, current.chapter - 1);
  //   }
  //   // Case 2: First chapter of the book, but not the first book.
  //   if (current.bookId > 1) {
  //     final previousBookId = current.bookId - 1;
  //     final lastChapterOfPreviousBook =
  //         bookIdToChapterCountMap[previousBookId]!;
  //     return ChapterIdentifier(previousBookId, lastChapterOfPreviousBook);
  //   }
  //   // Case 3: First chapter of the first book (Genesis 1).
  //   return null;
  // }

  // ChapterIdentifier? _getNextChapter(ChapterIdentifier current) {
  //   final totalChaptersInBook = bookIdToChapterCountMap[current.bookId]!;
  //   // Case 1: Not the last chapter of the book.
  //   if (current.chapter < totalChaptersInBook) {
  //     return ChapterIdentifier(current.bookId, current.chapter + 1);
  //   }
  //   // Case 2: Last chapter of the book, but not the last book.
  //   if (current.bookId < bookIdToChapterCountMap.length) {
  //     return ChapterIdentifier(current.bookId + 1, 1);
  //   }
  //   // Case 3: Last chapter of the last book (Revelation 22).
  //   return null;
  // }

  @override
  void dispose() {
    _manager.fontScaleNotifier.removeListener(_onFontScaleChanged);
    _manager.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Generate slivers first so keys are created in the map
    final sliversList = _displayedChapters.map((chapterId) {
      if (!_chapterKeys.containsKey(chapterId)) {
        _chapterKeys[chapterId] = GlobalKey();
      }
      return SliverToBoxAdapter(
        key: _chapterKeys[chapterId], // Attach GlobalKey
        child: HebrewGreekChapter(
          key: ValueKey('page-${chapterId.bookId}-${chapterId.chapter}'),
          bookId: chapterId.bookId,
          chapter: chapterId.chapter,
          fontSize: _fontSize,
        ),
      );
    }).toList();

    return RawGestureDetector(
      gestures: _zoomGesture,
      behavior: HitTestBehavior.translucent,
      child: Transform.scale(
        scale: _baseScale > 0 ? _currentScale / _baseScale : 1.0,
        alignment: _transformAlignment,
        child: CustomScrollView(
          controller: _scrollController,

          // Use the GlobalKey for the center
          center: _chapterKeys[_centerChapter],

          slivers: sliversList,
        ),
      ),
    );
  }
}

// @immutable
// class ChapterIdentifier {
//   final int bookId;
//   final int chapter;

//   const ChapterIdentifier(this.bookId, this.chapter);

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is ChapterIdentifier &&
//           runtimeType == other.runtimeType &&
//           bookId == other.bookId &&
//           chapter == other.chapter;

//   @override
//   int get hashCode => bookId.hashCode ^ chapter.hashCode;

//   @override
//   String toString() {
//     return 'ChapterIdentifier{bookId: $bookId, chapter: $chapter}';
//   }
// }
