import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';

typedef ChapterBuilder =
    Widget Function(BuildContext context, int bookId, int chapter);

class InfiniteScriptureScrollView extends StatefulWidget {
  const InfiniteScriptureScrollView({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.chapterBuilder,
    this.physics,
  });

  final int bookId;
  final int chapter;
  final ChapterBuilder chapterBuilder;
  final ScrollPhysics? physics;

  @override
  State<InfiniteScriptureScrollView> createState() =>
      _InfiniteScriptureScrollViewState();
}

class _InfiniteScriptureScrollViewState
    extends State<InfiniteScriptureScrollView> {
  late final ScrollController _scrollController;
  final List<ChapterIdentifier> _displayedChapters = [];
  late ChapterIdentifier _centerChapter;
  bool _isLoadingNextChapter = false;
  bool _isLoadingPreviousChapter = false;
  final Map<ChapterIdentifier, GlobalKey> _chapterKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_scrollListener);
    _resetChapters();
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
  void didUpdateWidget(covariant InfiniteScriptureScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _resetChapters();
    }
  }

  void _scrollListener() {
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

  @override
  void dispose() {
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

    return CustomScrollView(
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
    );
  }
}
