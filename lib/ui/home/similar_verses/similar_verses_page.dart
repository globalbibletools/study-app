import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/shared/verse_list_item.dart';

import 'similar_verse_manager.dart';

class SimilarVersesPage extends StatefulWidget {
  const SimilarVersesPage({
    super.key,
    required this.root,
    required this.strongsCode,
    required this.isRtl,
  });

  final String? root;
  final String strongsCode;
  final bool isRtl;

  @override
  State<SimilarVersesPage> createState() => _SimilarVersesPageState();
}

class _SimilarVersesPageState extends State<SimilarVersesPage> {
  final manager = SimilarVerseManager();

  TextDirection get _textDirection =>
      widget.isRtl ? TextDirection.rtl : TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    manager.init(widget.strongsCode);
  }

  String get title {
    if (widget.root == null) {
      return widget.strongsCode;
    }
    return '${widget.root} (${widget.strongsCode})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Directionality(
        textDirection: _textDirection,
        child: ValueListenableBuilder<List<Reference>>(
          valueListenable: manager.similarVersesNotifier,
          builder: (context, verseList, child) {
            return ListView.builder(
              itemCount: verseList.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.resultsCount(verseList.length),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                        fontSize: 20,
                      ),
                      // TODO: Support app language text direction after adding Arabic
                      textDirection: TextDirection.ltr,
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
                  textDirection: _textDirection,
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatReference(Reference reference) {
    final bookName = bookNameForId(context, reference.bookId);
    return '$bookName ${reference.chapter}:${reference.verse}';
  }
}
