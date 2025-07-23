import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/search/keyboard.dart';

import 'search_manager.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final manager = SearchPageManager();
  late final TextEditingController _controller;
  TextDirection _textDirection = TextDirection.rtl;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final prefix = _controller.text;
    manager.searchWordPrefix(prefix);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.search)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, right: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                readOnly: true, // non-editable by the system keyboard
                showCursor: true,
                textDirection: _textDirection,
                style: const TextStyle(fontSize: 24, fontFamily: 'sbl'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onTapOutside: (event) {
                  // empty to prevent losing focus
                },
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<SearchResults>(
                valueListenable: manager.resultsNotifier,
                builder: (context, results, child) {
                  return Directionality(
                    textDirection: _textDirection,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        switch (results) {
                          case NoResults():
                            return const SizedBox();
                          case WordSearchResults(words: final w):
                            final word = w[index];
                            return ListTile(
                              title: Text(
                                word,
                                style: TextStyle(fontFamily: 'sbl'),
                              ),
                              onTap: () {
                                manager.searchVerses(word);
                              },
                            );
                          case VerseSearchResults(
                            searchWord: final word,
                            references: final r,
                          ):
                            final fontSize = 30.0;
                            final reference = r[index];
                            final formattedReference = _formatReference(
                              reference,
                            );
                            return FutureBuilder<TextSpan>(
                              future: manager.getVerseContent(
                                word,
                                reference,
                                Theme.of(context).colorScheme.primary,
                                fontSize,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return ListTile(
                                    title: Text(formattedReference),
                                    subtitle: Text(
                                      'Error loading verse: ${snapshot.error}',
                                    ),
                                  );
                                }
                                if (snapshot.connectionState ==
                                    ConnectionState.done) {
                                  final verse = snapshot.data!;
                                  return ListTile(
                                    title: Text(
                                      formattedReference,
                                      style: TextStyle(
                                        fontFamily: 'sbl',
                                        fontSize: fontSize,
                                        color: Theme.of(context).disabledColor,
                                      ),
                                    ),
                                    subtitle: Text.rich(
                                      verse,
                                      textDirection: _textDirection,
                                    ),
                                  );
                                } else {
                                  // Giving the widget a height ensures that the
                                  // ListView.builder will not try to build the
                                  // every item in the list just because they all
                                  // theoretically fit with a zero height.
                                  return const SizedBox(height: 50);
                                }
                              },
                            );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            HebrewKeyboard(
              controller: _controller,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              keyColor: Theme.of(context).colorScheme.surface,
              keyTextColor: Theme.of(context).colorScheme.onSurface,
              onLanguageChange: (textDirection) {
                setState(() {
                  _textDirection = textDirection;
                });
              },
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
