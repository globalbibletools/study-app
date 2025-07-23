import 'package:flutter/material.dart';
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
    manager.search(prefix);
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
              child: ValueListenableBuilder(
                valueListenable: manager.resultsNotifier,
                builder: (context, results, child) {
                  return Directionality(
                    textDirection: _textDirection,
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final word = results[index];
                        return ListTile(
                          title: Text(
                            word,
                            style: TextStyle(fontFamily: 'sbl'),
                          ),
                        );
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
}
