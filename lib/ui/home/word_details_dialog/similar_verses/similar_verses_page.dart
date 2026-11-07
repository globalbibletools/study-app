import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/verse_list_item.dart';
import 'package:gbt/ui/common/word_popup.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/parallel_translations_sheet.dart';

import 'similar_verse_manager.dart';

enum SearchType { root, exact }

class SimilarVersesPage extends StatefulWidget {
  const SimilarVersesPage({
    super.key,
    required this.word,
    this.wordId,
    this.anchorReference,
    this.initialScrollOffset,
  });

  final WordDetails word;
  final String? wordId;
  final Reference? anchorReference;
  final double? initialScrollOffset;

  @override
  State<SimilarVersesPage> createState() => _SimilarVersesPageState();
}

class _SimilarVersesPageState extends State<SimilarVersesPage> {
  final manager = SimilarVerseManager();
  late final ScrollController _scrollController;
  SearchType _searchType = SearchType.root;

  TextDirection get _textDirection =>
      widget.word.isRtl ? TextDirection.rtl : TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset ?? 0.0,
    );
    manager.init(widget.word);
  }

  @override
  void dispose() {
    WordPopup.dismissActive();
    _scrollController.dispose();
    manager.dispose();
    super.dispose();
  }

  void _jumpToContext(Reference reference) {
    WordPopup.dismissActive();
    final contextData = OccurrenceSearchContext(
      word: widget.word,
      wordId: widget.wordId,
      searchType: _searchType,
      anchorReference: reference,
      scrollOffset: _scrollController.hasClients
          ? _scrollController.offset
          : 0.0,
    );
    final homeManager = getIt<HomeManager>();
    homeManager.jumpToContextReference(contextData);
    if (homeManager.wordStudySessionNotifier.value != null) {
      homeManager.setWordStudyOverlayVisible(false);
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: manager.rootNotifier,
          builder: (context, root, child) {
            if (root == null) return const SizedBox();
            return Text(root);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_rows_outlined),
            tooltip: l10n.parallelTranslations,
            onPressed: () => showParallelTranslationsSheet(
              context,
              onChanged: () => manager.reloadParallelVerses(),
            ),
          ),
        ],
      ),
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
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  manager.similarVersesNotifier,
                  manager.parallelVersesRevisionNotifier,
                ]),
                builder: (context, child) {
                  final verseList = manager.similarVersesNotifier.value;

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification ||
                          notification is ScrollUpdateNotification) {
                        WordPopup.dismissActive();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
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
                          wordsFuture: manager.getVerseWords(reference),
                          highlightPredicate: (word) =>
                              manager.isWordHighlighted(
                                word,
                                widget.word,
                                _searchType,
                              ),
                          formattedReference: formattedReference,
                          textDirection: _textDirection,
                          onReferenceTapped: () => _jumpToContext(reference),
                          parallelVerses: manager.getParallelVersesFor(
                            reference,
                          ),
                        );
                      },
                    ),
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
