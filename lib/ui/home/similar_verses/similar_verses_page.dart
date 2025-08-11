import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:studyapp/ui/shared/verse_list_item.dart';

import 'similar_verse_manager.dart';

enum SearchType { root, exact }

class SimilarVersesPage extends StatefulWidget {
  const SimilarVersesPage({super.key, required this.word});

  final WordDetails word;

  @override
  State<SimilarVersesPage> createState() => _SimilarVersesPageState();
}

class _SimilarVersesPageState extends State<SimilarVersesPage> {
  final manager = SimilarVerseManager();
  SearchType _searchType = SearchType.root;

  TextDirection get _textDirection =>
      widget.word.isRtl ? TextDirection.rtl : TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    manager.search(widget.word, _searchType);
  }

  String get title {
    return 'Word';
    // return (widget.root == null) ? '' : widget.root!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Directionality(
        textDirection: _textDirection,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: CupertinoSegmentedControl<SearchType>(
                children: {
                  SearchType.root: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(l10n.root),
                  ),
                  SearchType.exact: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(l10n.exact),
                  ),
                },
                onValueChanged: (SearchType value) {
                  setState(() {
                    _searchType = value;
                  });
                  manager.search(widget.word, value);
                },
                groupValue: _searchType,
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<Reference>>(
                valueListenable: manager.similarVersesNotifier,
                builder: (context, verseList, child) {
                  return ListView.builder(
                    itemCount: verseList.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Center(
                          child: Text(
                            l10n.resultsCount(verseList.length),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color?.withAlpha(178),
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
                          widget.word,
                          _searchType,
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
          ],
        ),
      ),
    );
  }

  String _formatReference(Reference reference) {
    final bookName = bookNameForId(context, reference.bookId);
    return '$bookName ${reference.chapter}:${reference.verse}';
  }
}
