import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:studyapp/common/bible_navigation.dart';

import 'scroll_sync_controller.dart';

typedef ChapterBuilder =
    Widget Function(BuildContext context, int bookId, int chapter);

class InfiniteScrollView extends StatefulWidget {
  const InfiniteScrollView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.chapterBuilder,
    this.physics,
    this.syncController,
  });

  final int bookId;
  final int chapter;
  final ChapterBuilder chapterBuilder;
  final ScrollPhysics? physics;
  final ScrollSyncController? syncController;

  @override
  State<InfiniteScrollView> createState() => _InfiniteScrollViewState();
}

class _InfiniteScrollViewState extends State<InfiniteScrollView> {
  late final ScrollController _scrollController;
  final List<ChapterIdentifier> _displayedChapters = [];
  late ChapterIdentifier _centerChapter;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  final Map<ChapterIdentifier, GlobalKey> _chapterKeys = {};
  final String _panelId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    widget.syncController?.addListener(_onSyncReceived);
    _resetChapters();
  }

  void _onSyncReceived() {
    final controller = widget.syncController!;

    // If THIS panel is the one the user is touching, ignore the update.
    if (controller.isSourceActive(_panelId)) return;
    if (controller.bookId == null || controller.chapter == null) return;

    final targetChapter = ChapterIdentifier(
      controller.bookId!,
      controller.chapter!,
    );

    // Check if we have the target chapter loaded
    if (_chapterKeys.containsKey(targetChapter)) {
      final key = _chapterKeys[targetChapter]!;
      final context = key.currentContext;

      if (context != null) {
        final renderSliver = context.findRenderObject() as RenderSliver?;
        if (renderSliver != null &&
            renderSliver.attached &&
            renderSliver.geometry != null) {
          final viewport = RenderAbstractViewport.of(renderSliver);
          final revealedOffset = viewport.getOffsetToReveal(renderSliver, 0.0);

          // CHANGED: Use 'geometry.scrollExtent' for height instead of 'size.height'
          final chapterHeight = renderSliver.geometry!.scrollExtent;

          final targetPixels =
              revealedOffset.offset + (chapterHeight * controller.progress);

          if (_scrollController.hasClients) {
            _scrollController.jumpTo(targetPixels);
          }
        }
      }
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

  @override
  void didUpdateWidget(covariant InfiniteScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _resetChapters();
    }
  }

  void _scrollListener() {
    _handleInfiniteScrollLoading();

    // Only calculate and report sync if WE are the active source
    if (widget.syncController != null &&
        widget.syncController!.isSourceActive(_panelId)) {
      _reportSyncPosition();
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
    final nextChapter = BibleNavigation.getNextChapter(lastChapter);

    if (nextChapter != null && mounted) {
      setState(() {
        _displayedChapters.add(nextChapter);
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingNextChapter = false;
  }

  Future<void> _loadPreviousChapter() async {
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

  void _reportSyncPosition() {
    // Find the chapter currently most visible in the viewport
    // A simple heuristic: find the chapter closest to offset 0 relative to viewport
    for (final chapterId in _displayedChapters) {
      final key = _chapterKeys[chapterId];
      if (key == null) continue;

      final context = key.currentContext;
      if (context == null) continue;

      final renderSliver = context.findRenderObject() as RenderSliver?;
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

      // Is this chapter currently intersecting the top of the screen?
      if (currentScroll >= revealedOffset &&
          currentScroll < revealedOffset + chapterHeight) {
        final double offsetIntoChapter = currentScroll - revealedOffset;
        final double progress = offsetIntoChapter / chapterHeight;

        widget.syncController!.updatePosition(
          _panelId,
          chapterId.bookId,
          chapterId.chapter,
          progress.clamp(0.0, 1.0),
        );
        break; // Found the active chapter, stop looking
      }
    }
  }

  @override
  void dispose() {
    widget.syncController?.removeListener(_onSyncReceived);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure keys exist
    for (var chapterId in _displayedChapters) {
      if (!_chapterKeys.containsKey(chapterId)) {
        _chapterKeys[chapterId] = GlobalKey();
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        physics: widget.physics,
        center: _chapterKeys[_centerChapter],
        slivers: _displayedChapters.map((chapterId) {
          return SliverToBoxAdapter(
            key: _chapterKeys[chapterId],
            child: widget.chapterBuilder(
              context,
              chapterId.bookId,
              chapterId.chapter,
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (widget.syncController == null) return false;

    // DETECT USER INTERACTION
    if (notification is ScrollStartNotification) {
      // If the user starts dragging this panel, claim 'Master' status
      if (notification.dragDetails != null) {
        widget.syncController!.setActiveSource(_panelId);
      }
    }

    // Optional: clear active source on scroll end if you want snapping behavior,
    // but usually keeping it active until the other panel is touched is smoother.
    return false;
  }
}
