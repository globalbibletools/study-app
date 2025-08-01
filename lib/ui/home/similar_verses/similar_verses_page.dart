import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/ui/shared/verse_list_item.dart';

import 'similar_verse_manager.dart';

class SimilarVersesPage extends StatefulWidget {
  const SimilarVersesPage({
    super.key,
    required this.strongsCode,
    required this.fontSize,
    required this.isRtl,
  });

  final String strongsCode;
  final double fontSize;
  final bool isRtl;

  @override
  State<SimilarVersesPage> createState() => _SimilarVersesPageState();
}

class _SimilarVersesPageState extends State<SimilarVersesPage> {
  final manager = SimilarVerseManager();

  @override
  void initState() {
    super.initState();
    manager.init(widget.strongsCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.strongsCode, style: TextStyle(fontFamily: 'sbl')),
      ),
      body: ValueListenableBuilder<List<Reference>>(
        valueListenable: manager.similarVersesNotifier,
        builder: (context, verseList, child) {
          return ListView.builder(
            itemCount: verseList.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Center(
                  child: Text(
                    '${verseList.length}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withAlpha(100),
                    ),
                  ),
                );
              }
              final referenceIndex = index - 1;
              final reference = verseList[referenceIndex];
              final formattedReference = _formatReference(reference);
              return VerseListItem(
                key: ValueKey(reference),
                verseContentFuture: manager.getVerseContent(
                  reference,
                  widget.strongsCode,
                  Theme.of(context).colorScheme.primary,
                  20.0,
                ),
                formattedReference: formattedReference,
                textDirection:
                    widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
              );
            },
          );
        },
      ),
    );
  }

  String _formatReference(Reference reference) {
    final bookName = bookNameForId(context, reference.bookId);
    return '$bookName ${reference.chapter}:${reference.verse}';
  }
}
