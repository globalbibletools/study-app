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
  final _focusNode = FocusNode();
  bool _isKeyboardVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final prefix = _controller.text;
    manager.searchWordPrefix(prefix);
  }

  void _onFocusChange() {
    // Update the state to show/hide the keyboard when focus changes
    if (_focusNode.hasFocus != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = _focusNode.hasFocus;
      });
    }
  }

  void _updateControllerWithoutTriggeringSearch(String text) {
    _controller.removeListener(_onTextChanged);

    // Update the controller's text and move the cursor to the end.
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
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
                focusNode: _focusNode,
                readOnly: true, // non-editable by the system keyboard
                showCursor: true,
                textDirection: _textDirection,
                style: const TextStyle(fontSize: 24, fontFamily: 'sbl'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _controller.clear();
                      // _focusNode.requestFocus();
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
                onTapOutside: (event) {
                  // empty to prevent losing focus
                },
                onTap: () {
                  // If tapped while unfocused, request focus and show word results again
                  if (!_focusNode.hasFocus) {
                    _focusNode.requestFocus();
                    manager.searchWordPrefix(_controller.text);
                  }
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
                                manager.fixHebrewFinalForms(word),
                                style: TextStyle(fontFamily: 'sbl'),
                              ),
                              onTap: () {
                                _updateControllerWithoutTriggeringSearch(word);
                                manager.searchVerses(word);
                                _focusNode.unfocus();
                              },
                            );
                          case VerseSearchResults(
                            searchWord: final word,
                            references: final r,
                          ):
                            final reference = r[index];
                            final formattedReference = _formatReference(
                              reference,
                            );
                            return VerseListItem(
                              key: ValueKey(
                                reference,
                              ), // Add a key for better performance
                              manager: manager,
                              searchWord: word,
                              reference: reference,
                              formattedReference: formattedReference,
                              textDirection: _textDirection,
                            );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            if (_isKeyboardVisible)
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
                fixHebrewFinalForms: manager.fixHebrewFinalForms,
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

class VerseListItem extends StatefulWidget {
  const VerseListItem({
    super.key,
    required this.manager,
    required this.searchWord,
    required this.reference,
    required this.formattedReference,
    required this.textDirection,
  });

  final SearchPageManager manager;
  final String searchWord;
  final Reference reference;
  final String formattedReference;
  final TextDirection textDirection;

  @override
  State<VerseListItem> createState() => _VerseListItemState();
}

// AutomaticKeepAliveClientMixin prevents the scrollview not to stutter when
// scrolling back. This is due to the future builder. If we can provide a non-
// future builder solution later, that would be better.  Maybe by fetching in
// batches or by sqlite3 synchronous fetches.
class _VerseListItemState extends State<VerseListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important: required by the mixin

    final fontSize = 20.0;

    return FutureBuilder<TextSpan>(
      future: widget.manager.getVerseContent(
        widget.searchWord,
        widget.reference,
        Theme.of(context).colorScheme.primary,
        fontSize,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListTile(
            title: Text(widget.formattedReference),
            subtitle: Text('Error loading verse: ${snapshot.error}'),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          final verse = snapshot.data!;
          return ListTile(
            title: Text(
              widget.formattedReference,
              style: TextStyle(
                fontFamily: 'sbl',
                color: Theme.of(context).disabledColor,
              ),
            ),
            subtitle: Text.rich(verse, textDirection: widget.textDirection),
          );
        } else {
          return const SizedBox(height: 75);
        }
      },
    );
  }
}
