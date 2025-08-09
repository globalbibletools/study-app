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
  bool _useSystemKeyboard = false;
  bool _isSwitchingKeyboard = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
    _textDirection = manager.savedTextDirection();
    _useSystemKeyboard = manager.shouldUseSystemKeyboard();
  }

  void _onTextChanged() {
    manager.searchWordPrefixAtCursor(_controller.value);
  }

  void _onFocusChange() {
    setState(() {});
  }

  Future<void> _toggleKeyboardType() async {
    // Switching FROM system keyboard TO in-app keyboard
    if (_useSystemKeyboard) {
      setState(() {
        // Step 1: Start the transition.
        // This makes the TextField readOnly, which starts dismissing the system keyboard.
        // The _isSwitchingKeyboard flag prevents the in-app keyboard from appearing immediately.
        _isSwitchingKeyboard = true;
        _useSystemKeyboard = false;
      });

      // Wait for the system keyboard's dismiss animation to finish.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      setState(() {
        // Step 2: End the transition.
        // The system keyboard is now gone, so show the in-app keyboard.
        _isSwitchingKeyboard = false;
      });
    } else {
      // Switching FROM in-app keyboard TO system keyboard is simple.
      // The in-app keyboard will disappear instantly, and the
      // system keyboard will be triggered by the TextField becoming editable.
      setState(() {
        _useSystemKeyboard = true;
      });
    }
  }

  void _updateControllerWithoutTriggeringSearch(String word) {
    _controller.removeListener(_onTextChanged);
    manager.clearCandidateList();
    _controller.value = manager.replaceWordAtCursor(_controller.value, word);
    _controller.addListener(_onTextChanged);
  }

  void _clearScreen() {
    _controller.clear();
    manager.searchWordPrefixAtCursor(_controller.value);
    manager.clearCandidateList();
    manager.clearVerseResults();
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
    final isRtl = _textDirection == TextDirection.rtl;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.search),
        actions: [
          IconButton(
            icon: Icon(
              _useSystemKeyboard
                  ? Icons.keyboard_hide_outlined
                  : Icons.keyboard_alt_outlined,
            ),
            tooltip:
                _useSystemKeyboard
                    ? AppLocalizations.of(context)!.useInAppKeyboard
                    : AppLocalizations.of(context)!.useSystemKeyboard,
            onPressed: () {
              _toggleKeyboardType();
              manager.setUseSystemKeyboard(_useSystemKeyboard);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: _textDirection,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: isRtl ? 8 : 16,
                  top: 8,
                  right: isRtl ? 16 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        focusNode: _focusNode,
                        readOnly: !_useSystemKeyboard,
                        showCursor: true,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 24, fontFamily: 'sbl'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _clearScreen,
                            icon: const Icon(Icons.clear),
                          ),
                        ),
                        onTapOutside: (event) {
                          // prevent macOS from losing focus when keyboard keys tapped
                        },
                        onSubmitted: manager.searchVerses,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        manager.clearCandidateList();
                        manager.searchVerses(_controller.text);
                        _focusNode.unfocus();
                      },
                      icon: Icon(Icons.search),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<VerseSearchResults?>(
                  valueListenable: manager.verseResultsNotifier,
                  builder: (context, results, child) {
                    if (results == null) {
                      return const SizedBox();
                    }

                    if (results.length == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          AppLocalizations.of(context)!.noVersesFound,
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      );
                    }

                    return Directionality(
                      textDirection: _textDirection,
                      child: ListView.builder(
                        itemCount: results.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Text(
                                  '${results.length}',
                                  style: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              ),
                            );
                          }
                          final reference = results.references[index - 1];
                          final formattedReference = _formatReference(
                            reference,
                          );
                          return VerseListItem(
                            key: ValueKey(reference),
                            verseContentFuture: manager.getVerseContent(
                              results.searchWords,
                              reference,
                              Theme.of(context).colorScheme.primary,
                              20.0,
                            ),
                            formattedReference: formattedReference,
                            textDirection: _textDirection,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_focusNode.hasFocus &&
                  !_useSystemKeyboard &&
                  !_isSwitchingKeyboard)
                HebrewGreekKeyboard(
                  controller: _controller,
                  backgroundColor:
                      Color.lerp(
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).colorScheme.surface,
                        0.5,
                      )!,
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
                  candidatesNotifier: manager.candidatesNotifier,
                  onCandidateTapped: (candidate) {
                    _updateControllerWithoutTriggeringSearch(candidate);
                  },
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
