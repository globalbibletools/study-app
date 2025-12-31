import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
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
        final newKey = GlobalKey();
        _chapterKeys[previousChapter] = newKey;
        _displayedChapters.insert(0, previousChapter);
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingPreviousChapter = false;
  }

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
