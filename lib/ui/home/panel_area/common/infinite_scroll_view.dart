import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';

export 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart'
    show
        ChapterGeometry,
        ChapterGeometryChangedNotification,
        ChapterGeometryProvider,
        GapSpan,
        SpanKind,
        VerseSpan;

const _topScrollOffset = 16.0;
const _syncTolerance = 0.005;

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
    this.syncController,
    this.onVisibleBookChanged,
  });

  final int bookId;
  final int chapter;
  final ChapterBuilder chapterBuilder;
  final ScrollPhysics? physics;
  final bool scrollingEnabled;
  final ScrollSyncController? syncController;
  final ValueChanged<int>? onVisibleBookChanged;

  @override
  State<InfiniteScrollView> createState() => InfiniteScrollViewState();
}

class InfiniteScrollViewState extends State<InfiniteScrollView> {
  late final _bibleNavigation = getIt<BibleNavigation>();
  late final ScrollController _scrollController;
  final List<ChapterIdentifier> _displayedChapters = [];
  late ChapterIdentifier _centerChapter;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  final Map<ChapterIdentifier, GlobalKey> _chapterKeys = {};
  final String _panelId = UniqueKey().toString();
  StreamSubscription? _verseJumpSubscription;
  VerseHighlight? _pendingJump;
  int _retryCount = 0;

  // Flag to prevent the scroll listener from overwriting the selected verse
  // with the geometrically visible verse during a programmatic jump.
  bool _isProgrammaticScroll = false;
  int? _lastVisibleBookId;

  // Last leader report, used for throttling.
  SyncPosition? _lastReportedPosition;
  Reference? _lastReportedDisplay;

  // Follower late-alignment retry (chapter data/geometry can arrive late).
  int _alignmentRetryCount = 0;
  bool _alignmentRetryScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    widget.syncController?.addListener(_onSyncReceived);

    if (widget.syncController != null) {
      _verseJumpSubscription = widget.syncController!.onVerseJump.listen(
        _handleVerseJump,
      );

      if (widget.syncController!.pendingVerseJump != null) {
        final pending = widget.syncController!.pendingVerseJump!;
        if (pending.bookId == widget.bookId &&
            pending.chapter == widget.chapter) {
          _pendingJump = pending;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pendingJump != null) {
              _handleVerseJump(_pendingJump!);
            }
          });
        }
      }
    }

    _resetChapters();

    if (widget.syncController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onSyncReceived();
        }
      });
    }
  }

  void _onSyncReceived() {
    _alignmentRetryCount = 0;
    _tryAlignToController();
  }

  void _tryAlignToController() {
    final controller = widget.syncController;
    if (controller == null) return;

    // If THIS panel is the one the user is touching, ignore the update.
    if (controller.isSourceActive(_panelId)) return;

    final position = controller.position;
    if (position == null) return;
    if (!_scrollController.hasClients) return;

    // If the truth lives in a chapter we have not loaded, re-center there.
    // Never do this while this panel is the active source (checked above).
    final targetChapter = SyncLayout(const []).chapterForPosition(position);
    if (targetChapter != null) {
      final targetId = ChapterIdentifier(
        targetChapter.bookId,
        targetChapter.chapter,
      );
      if (!_chapterKeys.containsKey(targetId)) {
        _resetChaptersTo(targetChapter.bookId, targetChapter.chapter);
        _scheduleAlignmentRetry();
        return;
      }
    }

    final layout = _buildSyncLayout();
    final targetPixels = layout?.resolvePosition(position);
    if (layout == null || targetPixels == null) {
      _scheduleAlignmentRetry();
      return;
    }

    final scrollPosition = _scrollController.position;
    final clamped = targetPixels.clamp(
      scrollPosition.minScrollExtent,
      scrollPosition.maxScrollExtent,
    );

    _alignmentRetryCount = 0;
    if ((_scrollController.offset - clamped).abs() > 0.5) {
      _isProgrammaticScroll = true;
      _scrollController.jumpTo(clamped);
      _isProgrammaticScroll = false;
    }
  }

  void _scheduleAlignmentRetry() {
    if (!mounted || _alignmentRetryScheduled) return;
    if (_alignmentRetryCount >= 20) return;

    _alignmentRetryCount++;
    _alignmentRetryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignmentRetryScheduled = false;
      if (!mounted) return;
      _tryAlignToController();
    });
  }

  void _resetChapters() {
    _resetChaptersTo(widget.bookId, widget.chapter);
  }

  void _resetChaptersTo(int bookId, int chapter) {
    setState(() {
      _centerChapter = ChapterIdentifier(bookId, chapter);
      _displayedChapters.clear();
      _chapterKeys.clear();

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

  ChapterGeometry? _geometryInSliver(BuildContext sliverContext) {
    ChapterGeometry? geometry;

    void visitor(Element element) {
      if (geometry != null) return;
      if (element is StatefulElement &&
          element.state is ChapterGeometryProvider) {
        geometry = (element.state as ChapterGeometryProvider).geometry;
      } else {
        element.visitChildren(visitor);
      }
    }

    sliverContext.visitChildElements(visitor);
    return geometry;
  }

  SyncLayout? _buildSyncLayout() {
    if (!_scrollController.hasClients || _displayedChapters.isEmpty) {
      return null;
    }

    final snapshots = <ChapterLayoutSnapshot>[];

    for (final chapterId in _displayedChapters) {
      final slice = _chapterSlice(chapterId);
      if (slice == null) continue;

      final key = _chapterKeys[chapterId];
      final context = key?.currentContext;
      if (context == null) continue;

      final geometry = _geometryInSliver(context);
      final verseCount = _bibleNavigation.getVerseCount(
        chapterId.bookId,
        chapterId.chapter,
      );

      snapshots.add(
        ChapterLayoutSnapshot(
          reference: Reference(
            bookId: chapterId.bookId,
            chapter: chapterId.chapter,
            verse: 1,
          ),
          top: slice.top,
          height: slice.height,
          geometry: geometry,
          firstVerse: geometry?.firstVerse ?? (verseCount > 0 ? 1 : null),
          lastVerse:
              geometry?.lastVerse ?? (verseCount > 0 ? verseCount : null),
        ),
      );
    }

    if (snapshots.isEmpty) return null;

    // Revelation 22 gets an extra bottom spacer in build(). Include it so the
    // bottom extreme resolves to the actual end of the scrollable.
    var trailingExtent = 0.0;
    final last = _displayedChapters.last;
    if (last.bookId == 66 && last.chapter == 22) {
      trailingExtent = 300.0;
    }

    return SyncLayout(snapshots, trailingExtent: trailingExtent);
  }

  int? getBookIdAtViewportOffset(double viewportY) {
    if (!_scrollController.hasClients) return null;

    // Calculate the absolute scroll coordinate of the touch
    final absoluteOffset = _scrollController.offset + viewportY;

    for (final chapterId in _displayedChapters) {
      final key = _chapterKeys[chapterId];
      if (key == null) continue;

      final sliverContext = key.currentContext;
      if (sliverContext == null) continue;

      final renderSliver = sliverContext.findRenderObject() as RenderSliver?;
      if (renderSliver == null ||
          !renderSliver.attached ||
          renderSliver.geometry == null) {
        continue;
      }

      final viewport = RenderAbstractViewport.of(renderSliver);
      final revealedOffset = viewport
          .getOffsetToReveal(renderSliver, 0.0)
          .offset;
      final chapterHeight = renderSliver.geometry!.scrollExtent;

      // Check if the touch lands inside this chapter's vertical slice
      if (absoluteOffset >= revealedOffset &&
          absoluteOffset < revealedOffset + chapterHeight) {
        return chapterId.bookId;
      }
    }
    return null;
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
        widget.syncController?.isSourceActive(_panelId) == true) {
      widget.syncController!.clearActiveSource();
    }
  }

  void _scrollListener() {
    _handleInfiniteScrollLoading();

    // If we are scrolling programmatically (jumping to a verse),
    // do not report geometric position. The jump logic handles reporting
    // the specific target verse.
    if (_isProgrammaticScroll) return;

    _updateVisibleBook();

    // Only calculate and report sync if WE are the active source
    if (widget.syncController != null &&
        widget.syncController!.isSourceActive(_panelId)) {
      _reportSyncPosition();
    }
  }

  void _updateVisibleBook() {
    if (widget.onVisibleBookChanged == null) return;
    for (final chapterId in _displayedChapters) {
      final key = _chapterKeys[chapterId];
      if (key == null) continue;
      final sliverContext = key.currentContext;
      if (sliverContext == null) continue;
      final renderSliver = sliverContext.findRenderObject() as RenderSliver?;
      if (renderSliver == null ||
          !renderSliver.attached ||
          renderSliver.geometry == null) {
        continue;
      }
      final viewport = RenderAbstractViewport.of(renderSliver);
      final revealedOffset = viewport
          .getOffsetToReveal(renderSliver, 0.0)
          .offset;
      final currentScroll = _scrollController.offset;
      final chapterHeight = renderSliver.geometry!.scrollExtent;
      if (currentScroll >= revealedOffset &&
          currentScroll < revealedOffset + chapterHeight) {
        if (chapterId.bookId != _lastVisibleBookId) {
          _lastVisibleBookId = chapterId.bookId;
          widget.onVisibleBookChanged!(chapterId.bookId);
        }
        break;
      }
    }
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
  void _reportSyncPosition({bool force = false}) {
    final controller = widget.syncController;
    if (controller == null || !_scrollController.hasClients) return;

    final layout = _buildSyncLayout();
    if (layout == null) return;

    final leader = layout.leaderAt(
      _scrollController.offset,
      _scrollController.position.viewportDimension,
    );
    if (leader == null) return;

    final position = leader.position;
    final display = leader.displayReference;

    if (!force &&
        _lastReportedPosition != null &&
        _lastReportedPosition!.from == position.from &&
        _lastReportedPosition!.to == position.to &&
        (position.t - _lastReportedPosition!.t).abs() < _syncTolerance &&
        _lastReportedDisplay == display) {
      return;
    }

    _lastReportedPosition = position;
    _lastReportedDisplay = display;

    controller.updatePosition(
      _panelId,
      position,
      displayVerse: display?.verse,
      displayReference: display,
    );
  }

  @override
  void dispose() {
    _verseJumpSubscription?.cancel();
    widget.syncController?.removeListener(_onSyncReceived);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleVerseJump(VerseHighlight target) {
    // If this specific panel is being touched/dragged by the user, ignore auto-scrolls.
    if (widget.syncController != null &&
        widget.syncController!.isSourceActive(_panelId) &&
        target.isAuto) {
      return;
    }

    // Find if the target chapter is currently displayed
    // We construct a temporary ID to look up the key
    final targetId = ChapterIdentifier(target.bookId, target.chapter);
    final key = _chapterKeys[targetId];
    if (key == null || key.currentContext == null) {
      _scheduleRetry(target);
      return;
    }

    // Get context using the specific chapter's key
    final sliverContext = key.currentContext!;
    final renderSliver = sliverContext.findRenderObject() as RenderSliver?;
    if (renderSliver == null || renderSliver.geometry == null) {
      _scheduleRetry(target);
      return;
    }

    ChapterGeometry? geometry;
    State? actualState;

    void visitor(Element element) {
      if (geometry != null) return;
      if (element is StatefulElement &&
          element.state is ChapterGeometryProvider) {
        final provider = element.state as ChapterGeometryProvider;
        geometry = provider.geometry;
        actualState = element.state;
      } else {
        element.visitChildren(visitor);
      }
    }

    sliverContext.visitChildElements(visitor);

    if (geometry != null && actualState != null) {
      // Verse 1 deliberately shows the chapter title above it.
      final verseOffset = target.verse == 1
          ? 0.0
          : geometry!.spans[target.verse]?.start;

      if (verseOffset == null) {
        _scheduleRetry(target);
        return;
      }

      _pendingJump = null;
      _retryCount = 0;
      widget.syncController?.clearPendingJump();

      _isProgrammaticScroll = true;
      widget.syncController?.setActiveSource(_panelId);

      // Perform the scroll (Animate if Auto, Jump if Manual) and report the
      // actual landed unit afterwards, so jump styling stays a separate layer.
      () async {
        await _scrollToAbsolutePosition(
          actualState!.context,
          verseOffset,
          animate: target.isAuto,
          verseNumber: target.verse,
        );

        if (!mounted) return;
        _isProgrammaticScroll = false;
        if (widget.syncController == null) return;

        if (widget.syncController!.isSourceActive(_panelId)) {
          _reportSyncPosition(force: true);
          widget.syncController!.clearActiveSource();
        }
      }();
    } else {
      _scheduleRetry(target);
    }
  }

  void _scheduleRetry(VerseHighlight target) {
    _pendingJump = target;
    if (_retryCount < 10) {
      _retryCount++;
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _pendingJump != null) {
          _handleVerseJump(_pendingJump!);
        }
      });
    }
  }

  Future<void> _scrollToAbsolutePosition(
    BuildContext chapterContext,
    double offsetInsideChapter, {
    required bool animate,
    required int verseNumber,
  }) async {
    // Calculate absolute scroll position
    final renderObject = chapterContext.findRenderObject();
    if (renderObject is! RenderBox) return;

    final viewport = RenderAbstractViewport.of(renderObject);
    final revealedOffset = viewport.getOffsetToReveal(renderObject, 0.0);

    // Add the verse's internal offset
    double targetPixels = revealedOffset.offset + offsetInsideChapter;

    // Subtract 16 pixels so the verse isn't glued to the top of the viewport,
    // unless it's verse 1 (which has the chapter title above it).
    if (verseNumber > 1) {
      targetPixels -= _topScrollOffset;
    }

    // Clamp to bounds
    targetPixels = targetPixels.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      await _scrollController.animateTo(
        targetPixels,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(targetPixels);
    }
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

    // Add extra padding only if we are at the very end of Revelation
    if (_displayedChapters.isNotEmpty) {
      final last = _displayedChapters.last;
      if (last.bookId == 66 && last.chapter == 22) {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 300)));
      }
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
    if (widget.syncController == null) return false;

    if (!widget.scrollingEnabled &&
        notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      return false;
    }

    // Detect Start of Manual Drag
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isProgrammaticScroll = false;
        widget.syncController!.setActiveSource(_panelId);
      }
    }

    // Detect End of Manual Drag / Momentum
    if (notification is ScrollEndNotification) {
      // A programmatic verse jump keeps ownership until it reports the unit
      // it actually landed on.
      if (!_isProgrammaticScroll &&
          widget.syncController!.isSourceActive(_panelId)) {
        widget.syncController!.clearActiveSource();
      }
    }

    // Detect Size Changes (Zooming or Loading)
    if (notification is SizeChangedLayoutNotification ||
        notification is ChapterGeometryChangedNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Check who is the active source
        if (widget.syncController!.isSourceActive(_panelId)) {
          // Case A: We are the active source (User zoomed us).
          if (!_isProgrammaticScroll) {
            _reportSyncPosition();
          }
        } else {
          // Case B: We are the other panel.
          // Re-align ourselves to match the active panel's target.
          _onSyncReceived();
        }
      });
    }

    return false;
  }
}
