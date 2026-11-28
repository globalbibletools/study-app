import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';

export 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart'
    show ChapterGeometry, ChapterGeometryChangedNotification, VerseSpan;

const _topScrollOffset = 16.0;

/// Deltas smaller than this are not worth animating; jump straight there.
const _animatedSeekMinDelta = 1.0;

/// Padding added below the last chapter of scripture so it can scroll fully
/// into view. Mirrored in [_buildSyncLayout] so the bottom extreme of the
/// scrollable resolves to the real end of the content.
const _scriptureEndPadding = 300.0;

typedef ChapterBuilder =
    Widget Function(BuildContext context, int bookId, int chapter);

class InfiniteScrollView extends StatefulWidget {
  const InfiniteScrollView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.chapterBuilder,
    this.physics,
    this.scrollingEnabled = true,
    this.onVisibleBookChanged,
  });

  final int bookId;
  final int chapter;
  final ChapterBuilder chapterBuilder;
  final ScrollPhysics? physics;
  final bool scrollingEnabled;
  final ValueChanged<int>? onVisibleBookChanged;

  @override
  State<InfiniteScrollView> createState() => InfiniteScrollViewState();
}

class InfiniteScrollViewState extends State<InfiniteScrollView> {
  final _bibleNavigation = getIt<BibleNavigation>();
  final _navigationViewModel = getIt<NavigationViewModel>();
  late final ScrollController _scrollController;
  final List<ChapterIdentifier> _displayedChapters = [];
  late ChapterIdentifier _centerChapter;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  final Map<ChapterIdentifier, GlobalKey> _chapterKeys = {};
  final Map<ChapterIdentifier, ChapterGeometry?> _chapterGeometries = {};
  final String _panelId = UniqueKey().toString();
  int? _lastVisibleBookId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _navigationViewModel.addListener(_onSyncReceived);

    _resetChapters();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _onSyncReceived();
      }
    });
  }

  void _onSyncReceived() {
    _tryAlignToController();
  }

  void _tryAlignToController() {
    final controller = _navigationViewModel;

    // If THIS panel is the one the user is touching, ignore the update.
    if (controller.isSourceActive(_panelId)) return;

    final position = controller.position;
    if (position == null) return;
    if (!_scrollController.hasClients) return;

    // If the truth lives in a chapter we have not loaded, re-center there.
    // Never do this while this panel is the active source (checked above).
    // Alignment resumes once the new chapters publish their geometry.
    final targetChapter = SyncLayout(const []).chapterForPosition(position);
    if (targetChapter != null) {
      final targetId = ChapterIdentifier(
        targetChapter.bookId,
        targetChapter.chapter,
      );
      if (!_chapterKeys.containsKey(targetId)) {
        _resetChaptersTo(targetChapter.bookId, targetChapter.chapter);
        return;
      }
    }

    final layout = _buildSyncLayout();
    var targetPixels = layout?.resolvePosition(position);
    if (layout == null || targetPixels == null) return;

    // Explicit seeks get a little breathing room at the top of the viewport,
    // but verse 1 already has the chapter title above it. Scroll-follow
    // alignment must not apply this: leaders and followers have to resolve
    // anchors identically or continuous sync drifts.
    if (controller.lastUpdateIsSeek) {
      final targetVerse = position.from.ref?.verse ?? 1;
      if (targetVerse > 1) targetPixels -= _topScrollOffset;
    }

    final scrollPosition = _scrollController.position;
    final clamped = targetPixels.clamp(
      scrollPosition.minScrollExtent,
      scrollPosition.maxScrollExtent,
    );

    final delta = (_scrollController.offset - clamped).abs();
    if (delta <= 0.5) return;

    if (controller.lastUpdateAnimated && delta > _animatedSeekMinDelta) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  void _resetChapters() {
    _resetChaptersTo(widget.bookId, widget.chapter);
  }

  void _resetChaptersTo(int bookId, int chapter) {
    setState(() {
      _centerChapter = ChapterIdentifier(bookId, chapter);
      _displayedChapters.clear();
      _chapterKeys.clear();
      _chapterGeometries.clear();

      final previousChapter = _bibleNavigation.getPreviousChapter(
        _centerChapter,
      );
      if (previousChapter != null) {
        _displayedChapters.add(previousChapter);
        _chapterKeys[previousChapter] = GlobalKey();
      }
      _displayedChapters.add(_centerChapter);
      _chapterKeys[_centerChapter] = GlobalKey();
    });
  }

  ({double top, double height})? _chapterSlice(ChapterIdentifier chapterId) {
    final key = _chapterKeys[chapterId];
    final sliverContext = key?.currentContext;
    if (sliverContext == null) return null;

    final renderSliver = sliverContext.findRenderObject() as RenderSliver?;
    if (renderSliver == null ||
        !renderSliver.attached ||
        renderSliver.geometry == null) {
      return null;
    }

    final viewport = RenderAbstractViewport.of(renderSliver);
    final top = viewport.getOffsetToReveal(renderSliver, 0.0).offset;
    return (top: top, height: renderSliver.geometry!.scrollExtent);
  }

  SyncLayout? _buildSyncLayout() {
    if (!_scrollController.hasClients || _displayedChapters.isEmpty) {
      return null;
    }

    final snapshots = <ChapterLayoutSnapshot>[];

    for (final chapterId in _displayedChapters) {
      final slice = _chapterSlice(chapterId);
      if (slice == null) continue;

      snapshots.add(
        ChapterLayoutSnapshot(
          reference: Reference(
            bookId: chapterId.bookId,
            chapter: chapterId.chapter,
            verse: 1,
          ),
          top: slice.top,
          height: slice.height,
          geometry: _chapterGeometries[chapterId],
        ),
      );
    }

    if (snapshots.isEmpty) return null;

    // The last chapter of scripture gets an extra bottom spacer in build().
    // Include it so the bottom extreme resolves to the actual end of the
    // scrollable.
    final trailingExtent = _isAtEndOfScripture ? _scriptureEndPadding : 0.0;

    return SyncLayout(snapshots, trailingExtent: trailingExtent);
  }

  bool get _isAtEndOfScripture =>
      _bibleNavigation.getNextChapter(_displayedChapters.last) == null;

  /// The chapter occupying [absoluteOffset] in scroll coordinates, if any.
  ChapterIdentifier? _chapterAtOffset(double absoluteOffset) {
    for (final chapterId in _displayedChapters) {
      final slice = _chapterSlice(chapterId);
      if (slice == null) continue;
      if (absoluteOffset >= slice.top &&
          absoluteOffset < slice.top + slice.height) {
        return chapterId;
      }
    }
    return null;
  }

  int? getBookIdAtViewportOffset(double viewportY) {
    if (!_scrollController.hasClients) return null;

    // Calculate the absolute scroll coordinate of the touch
    final chapter = _chapterAtOffset(_scrollController.offset + viewportY);
    return chapter?.bookId;
  }

  @override
  void didUpdateWidget(covariant InfiniteScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _resetChapters();
    }
    if (!widget.scrollingEnabled &&
        oldWidget.scrollingEnabled &&
        _navigationViewModel.isSourceActive(_panelId)) {
      _navigationViewModel.clearActiveSource();
    }
  }

  void _scrollListener() {
    _handleInfiniteScrollLoading();
    _updateVisibleBook();

    // Only calculate and report sync if WE are the active source
    if (_navigationViewModel.isSourceActive(_panelId)) {
      _reportSyncPosition();
    }
  }

  void _updateVisibleBook() {
    final onVisibleBookChanged = widget.onVisibleBookChanged;
    if (onVisibleBookChanged == null) return;

    final bookId = _chapterAtOffset(_scrollController.offset)?.bookId;
    if (bookId == null || bookId == _lastVisibleBookId) return;

    _lastVisibleBookId = bookId;
    onVisibleBookChanged(bookId);
  }

  void _handleInfiniteScrollLoading() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadNextChapter();
    }
    if (_scrollController.position.pixels <
        _scrollController.position.minScrollExtent + 400) {
      _loadPreviousChapter();
    }
  }

  Future<void> _loadNextChapter() async {
    if (_isLoadingNextChapter || _displayedChapters.isEmpty) return;
    _isLoadingNextChapter = true;

    final lastChapter = _displayedChapters.last;
    final nextChapter = _bibleNavigation.getNextChapter(lastChapter);

    if (nextChapter != null && mounted) {
      setState(() {
        _displayedChapters.add(nextChapter);
        _chapterKeys[nextChapter] = GlobalKey();
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingNextChapter = false;
  }

  Future<void> _loadPreviousChapter() async {
    if (_isLoadingPreviousChapter || _displayedChapters.isEmpty) return;
    _isLoadingPreviousChapter = true;

    final firstChapter = _displayedChapters.first;
    final previousChapter = _bibleNavigation.getPreviousChapter(firstChapter);

    if (previousChapter != null && mounted) {
      setState(() {
        _displayedChapters.insert(0, previousChapter);
        _chapterKeys[previousChapter] = GlobalKey();
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingPreviousChapter = false;
  }

  /// Reports the leader's current interval to the sync controller.
  void _reportSyncPosition() {
    final controller = _navigationViewModel;
    if (!_scrollController.hasClients) return;

    final layout = _buildSyncLayout();
    if (layout == null) return;

    final leader = layout.leaderAt(
      _scrollController.offset,
      _scrollController.position.viewportDimension,
    );
    if (leader == null) return;

    controller.reportPosition(
      _panelId,
      leader.position,
      display: leader.displayReference,
    );
  }

  @override
  void dispose() {
    _navigationViewModel.removeListener(_onSyncReceived);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slivers = _displayedChapters.map((chapterId) {
      return SliverToBoxAdapter(
        key: _chapterKeys[chapterId],
        child: SizeChangedLayoutNotifier(
          child: widget.chapterBuilder(
            context,
            chapterId.bookId,
            chapterId.chapter,
          ),
        ),
      );
    }).toList();

    // Add extra padding so the last chapter of scripture can scroll fully
    // into view.
    if (_isAtEndOfScripture) {
      slivers.add(
        const SliverToBoxAdapter(child: SizedBox(height: _scriptureEndPadding)),
      );
    }

    return NotificationListener<Notification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        physics: widget.scrollingEnabled
            ? widget.physics
            : const NeverScrollableScrollPhysics(),
        center: _chapterKeys[_centerChapter],
        slivers: slivers,
      ),
    );
  }

  bool _onScrollNotification(Notification notification) {
    if (notification is ChapterGeometryChangedNotification) {
      _chapterGeometries[ChapterIdentifier(
            notification.bookId,
            notification.chapter,
          )] =
          notification.geometry;
    }

    if (!widget.scrollingEnabled &&
        notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      return false;
    }

    // Detect Start of Manual Drag
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _navigationViewModel.setActiveSource(_panelId);
      }
    }

    // Detect End of Manual Drag / Momentum
    if (notification is ScrollEndNotification) {
      if (_navigationViewModel.isSourceActive(_panelId)) {
        _navigationViewModel.clearActiveSource();
      }
    }

    // Detect Size Changes (Zooming or Loading)
    if (notification is SizeChangedLayoutNotification ||
        notification is ChapterGeometryChangedNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Check who is the active source
        if (_navigationViewModel.isSourceActive(_panelId)) {
          // Case A: We are the active source (User zoomed us).
          _reportSyncPosition();
        } else {
          // Case B: We are the other panel.
          // Re-align ourselves to match the active panel's target.
          _onSyncReceived();
        }
      });
      // Geometry is often published from a post-frame callback, where adding
      // another post-frame callback does not itself schedule a frame.
      WidgetsBinding.instance.ensureVisualUpdate();
    }

    return false;
  }
}
