import 'package:database_builder/database_builder.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/search/keyboard.dart';
import 'package:studyapp/ui/shared/verse_list_item.dart';

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
    _textDirection = manager.savedTextDirection();
  }

  void _onTextChanged() {
    manager.searchWordPrefix(_controller.value);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = _focusNode.hasFocus;
      });
    }
  }

  void _updateControllerWithoutTriggeringSearch(String word) {
    _controller.removeListener(_onTextChanged);

    // Update the controller's text and move the cursor to the end.
    final replaced = manager.replaceWordAtCursor(_controller.value, word);
    _controller.text = replaced;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );

    _controller.addListener(_onTextChanged);
  }

  void _clearScreen() {
    _controller.clear();
    manager.searchWordPrefix(_controller.value);
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
        child: Directionality(
          textDirection: _textDirection,
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
                  style: const TextStyle(fontSize: 24, fontFamily: 'sbl'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _clearScreen,
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                  onTapOutside: (event) {
                    // empty to prevent losing focus
                  },
                  onTap: () {
                    if (!_focusNode.hasFocus) {
                      _focusNode.requestFocus();
                      manager.searchWordPrefix(_controller.value);
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
                                  fixFinalForms(word),
                                  style: TextStyle(fontFamily: 'sbl'),
                                ),
                                onTap: () {
                                  _updateControllerWithoutTriggeringSearch(
                                    word,
                                  );
                                  manager.searchVerses(_controller.text);
                                  _focusNode.unfocus();
                                },
                              );
                            case VerseSearchResults(
                              searchWords: final words,
                              references: final r,
                            ):
                              final reference = r[index];
                              final formattedReference = _formatReference(
                                reference,
                              );
                              return VerseListItem(
                                key: ValueKey(reference),
                                verseContentFuture: manager.getVerseContent(
                                  words,
                                  reference,
                                  Theme.of(context).colorScheme.primary,
                                  20.0,
                                ),
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
                HebrewGreekKeyboard(
                  controller: _controller,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  keyColor: Theme.of(context).colorScheme.surface,
                  keyTextColor: Theme.of(context).colorScheme.onSurface,
                  onLanguageChange: (textDirection) {
                    setState(() {
                      _textDirection = textDirection;
                      manager.saveDirection(textDirection);
                      _clearScreen();
                    });
                  },
                  fixFinalForms: fixFinalForms,
                  isHebrew: _textDirection == TextDirection.rtl,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatReference(Reference reference) {
    final bookName = bookNameForId(context, reference.bookId);
    return '$bookName ${reference.chapter}:${reference.verse}';
  }
}
