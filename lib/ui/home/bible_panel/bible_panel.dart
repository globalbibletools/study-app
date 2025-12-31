import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'bible_chapter.dart';

class BiblePanel extends StatefulWidget {
  const BiblePanel({super.key, required this.bookId, required this.chapter});

  final int bookId;
  final int chapter;

  @override
  State<BiblePanel> createState() => _BiblePanelState();
}

class _BiblePanelState extends State<BiblePanel> {
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

      // Load current and previous (optional, mirroring HebrewGreekPanel logic)
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
  void didUpdateWidget(covariant BiblePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookId != oldWidget.bookId ||
        widget.chapter != oldWidget.chapter) {
      _resetChapters();
    }
  }

  void _scrollListener() {
    // Load next when near bottom
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadNextChapter();
    }
    // Load previous when near top
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
        final currentOffset = _scrollController.offset;
        final newKey = GlobalKey();
        _chapterKeys[previousChapter] = newKey;
        _displayedChapters.insert(0, previousChapter);
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
    // Tiny delay to prevent double-triggering
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
    // 1. Generate the list of slivers FIRST.
    // This forces the map loop to run, ensuring that _chapterKeys is populated
    // with the GlobalKeys for every displayed chapter before we try to use them.
    final sliversList = _displayedChapters.map((chapterId) {
      if (!_chapterKeys.containsKey(chapterId)) {
        _chapterKeys[chapterId] = GlobalKey();
      }
      final key = _chapterKeys[chapterId];

      return SliverToBoxAdapter(
        key: key, // This is the GlobalKey
        child: BibleChapter(
          key: ValueKey('bible-${chapterId.bookId}-${chapterId.chapter}'),
          bookId: chapterId.bookId,
          chapter: chapterId.chapter,
        ),
      );
    }).toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        controller: _scrollController,

        // 2. Use the GlobalKey for the center chapter.
        // Since we generated the list above, we know this key exists in the map now.
        center: _chapterKeys[_centerChapter],

        slivers: sliversList,
      ),
    );
  }
}
