import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:studyapp/common/bible_navigation.dart';

import 'scroll_sync_controller.dart';

typedef ChapterBuilder =
    Widget Function(BuildContext context, int bookId, int chapter);

mixin VerseScrollable {
  /// Returns the vertical offset (pixels) of the verse relative to the top of the widget.
  /// Returns null if the verse is not found.
  double? getOffsetForVerse(int verseNumber);

  /// Returns the verse number at the given vertical offset (pixels) relative to the top of the widget.
  /// Returns null if no specific verse is found.
  int? getVerseForOffset(double yOffset);
}

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
  StreamSubscription? _verseJumpSubscription;

  // Flag to prevent the scroll listener from overwriting the selected verse
  // with the geometrically visible verse during a programmatic jump.
  bool _isProgrammaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    widget.syncController?.addListener(_onSyncReceived);

    if (widget.syncController != null) {
      _verseJumpSubscription = widget.syncController!.onVerseJump.listen(
        _handleVerseJump,
      );
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
          final chapterHeight = renderSliver.geometry!.scrollExtent;
          if (chapterHeight == 0) return;

          final targetPixels =
              revealedOffset.offset + (chapterHeight * controller.progress);

          if (_scrollController.hasClients) {
            _scrollController.jumpTo(targetPixels);

            // If the driver (Bottom Panel) didn't provide a verse (verse == null),
            // and we (Top Panel) are able to calculate it, report it back.
            if (controller.verse == null) {
              final detectedVerse = _findVisibleVerse();
              if (detectedVerse != null) {
                controller.reportAutoDetectedVerse(detectedVerse);
              }
            }
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
        _chapterKeys[previousChapter] = GlobalKey();
      }
      _displayedChapters.add(_centerChapter);
      _chapterKeys[_centerChapter] = GlobalKey();
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

    // If we are scrolling programmatically (jumping to a verse),
    // do not report geometric position. The jump logic handles reporting
    // the specific target verse.
    if (_isProgrammaticScroll) return;

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
    final previousChapter = BibleNavigation.getPreviousChapter(firstChapter);

    if (previousChapter != null && mounted) {
      setState(() {
        _displayedChapters.insert(0, previousChapter);
        _chapterKeys[previousChapter] = GlobalKey();
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
    _isLoadingPreviousChapter = false;
  }

  /// Extracted logic to find the visible verse at the current scroll offset.
  int? _findVisibleVerse() {
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

      // Is this chapter currently intersecting the top of the screen?
      if (currentScroll >= revealedOffset &&
          currentScroll < revealedOffset + chapterHeight) {
        final double offsetIntoChapter = currentScroll - revealedOffset;

        // Determine the verse
        VerseScrollable? scrollableState;

        void visitor(Element element) {
          if (scrollableState != null) return;
          if (element is StatefulElement && element.state is VerseScrollable) {
            scrollableState = element.state as VerseScrollable;
          } else {
            element.visitChildren(visitor);
          }
        }

        sliverContext.visitChildElements(visitor);

        if (scrollableState != null) {
          return scrollableState!.getVerseForOffset(offsetIntoChapter);
        }
        break;
      }
    }
    return null;
  }

  void _reportSyncPosition() {
    // 1. Find the visible chapter (Sliver)
    // 2. Calculate progress
    // 3. Find visible Verse

    // We duplicate the finding logic slightly here to get the 'progress'
    // variables which _findVisibleVerse doesn't return.

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
        final double offsetIntoChapter = currentScroll - revealedOffset;
        final double progress = offsetIntoChapter / chapterHeight;

        // Use the helper to get the verse specifically
        final visibleVerse = _findVisibleVerse();

        widget.syncController!.updatePosition(
          _panelId,
          chapterId.bookId,
          chapterId.chapter,
          progress.clamp(0.0, 1.0),
          verse: visibleVerse,
        );
        break;
      }
    }
  }

  @override
  void dispose() {
    _verseJumpSubscription?.cancel();
    widget.syncController?.removeListener(_onSyncReceived);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleVerseJump(int verse) {
    // 1. Get the Key for the center/current chapter
    final key = _chapterKeys[_centerChapter];
    if (key == null) return;

    // 2. Get the Context of the Sliver
    final sliverContext = key.currentContext;
    if (sliverContext == null) return;

    // 3. Find the RenderSliver (for height calculation)
    final renderSliver = sliverContext.findRenderObject() as RenderSliver?;
    if (renderSliver == null || renderSliver.geometry == null) return;

    // 4. Find the State
    VerseScrollable? scrollableState;
    State? actualState;

    void visitor(Element element) {
      if (scrollableState != null) return;

      if (element is StatefulElement && element.state is VerseScrollable) {
        scrollableState = element.state as VerseScrollable;
        actualState = element.state;
      } else {
        element.visitChildren(visitor);
      }
    }

    sliverContext.visitChildElements(visitor);

    // 5. Perform the scroll using the generic mixin
    if (scrollableState != null && actualState != null) {
      final verseOffset = scrollableState!.getOffsetForVerse(verse);

      if (verseOffset != null) {
        _isProgrammaticScroll = true; // Lock geometric updates

        widget.syncController?.setActiveSource(_panelId);

        // Calculate progress so other panels can follow correctly
        final double chapterHeight = renderSliver.geometry!.scrollExtent;
        final double progress = chapterHeight > 0
            ? verseOffset / chapterHeight
            : 0.0;

        // Explicitly report the target verse so the UI updates to exactly what was clicked
        // instead of what geometry thinks (e.g. verse 16 might be at pixel 0).
        widget.syncController!.updatePosition(
          _panelId,
          _centerChapter.bookId,
          _centerChapter.chapter,
          progress.clamp(0.0, 1.0),
          verse: verse,
        );

        _scrollToAbsolutePosition(actualState!.context, verseOffset);

        // Release the lock after the frame renders and scroll settles
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isProgrammaticScroll = false;
        });
      } else {
        log("Verse $verse not found in current layout");
      }
    }
  }

  void _scrollToAbsolutePosition(
    BuildContext chapterContext,
    double offsetInsideChapter,
  ) {
    // Calculate absolute scroll position
    final renderObject = chapterContext.findRenderObject();
    if (renderObject is! RenderBox) return;

    // This finds the scroll offset required to bring the *top* of the chapter
    // to the top of the viewport.
    final viewport = RenderAbstractViewport.of(renderObject);
    final revealedOffset = viewport.getOffsetToReveal(renderObject, 0.0);

    // 5. Add the verse's internal offset
    // You might want to subtract a little padding (e.g. 20px) so the verse isn't
    // glued to the very top edge.
    double targetPixels = revealedOffset.offset + offsetInsideChapter;

    // Optional: Clamp to bounds
    targetPixels = targetPixels.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.jumpTo(targetPixels);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onScrollNotification,
      child: CustomScrollView(
        controller: _scrollController,
        physics: widget.physics,
        // keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        center: _chapterKeys[_centerChapter],
        slivers: _displayedChapters.map((chapterId) {
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
        }).toList(),
      ),
    );
  }

  bool _onScrollNotification(Notification notification) {
    if (widget.syncController == null) return false;

    // 1. Detect Dragging (Active Panel logic)
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        // User manually touched the screen, so we respect geometric calculations again
        _isProgrammaticScroll = false;
        widget.syncController!.setActiveSource(_panelId);
      }
    }

    // 2. Detect Size Changes (Zooming or Loading)
    if (notification is SizeChangedLayoutNotification) {
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
