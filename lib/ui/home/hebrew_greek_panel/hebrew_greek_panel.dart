import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/chapter_page.dart';

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
  @override
  Widget build(BuildContext context) {
    const centerKey = ValueKey<String>('bottom-sliver-list');
    return CustomScrollView(
      center: centerKey,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            return _buildChapter();
          }, childCount: 1),
        ),
        SliverList(
          key: centerKey,
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            return ChapterPage(
              key: ValueKey('${widget.bookId}-${widget.chapter}'),
              bookId: widget.bookId,
              chapter: widget.chapter,
            );
          }, childCount: 1),
        ),
      ],
    );
  }

  ChapterPage _buildChapter() {
    return ChapterPage(
      key: ValueKey('${widget.bookId}-${widget.chapter}'),
      bookId: widget.bookId,
      chapter: widget.chapter,
    );
  }
}
