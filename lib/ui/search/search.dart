import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/search/keyboard.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  bool _isKeyboardVisible = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // Add a listener to the text field's focus node
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      // Show keyboard when the text field has focus, hide otherwise
      _isKeyboardVisible = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
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
                focusNode: _focusNode,
                // Important: This makes the text field non-editable by the system keyboard,
                // but still allows it to show a cursor and be manipulated by our custom keyboard.
                readOnly: true,
                showCursor: true,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 24, fontFamily: 'sbl'),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onTapOutside: (event) {
                  // empty to prevent losing focus
                },
              ),
            ),
            Expanded(child: ListView()),
            if (_isKeyboardVisible)
              HebrewKeyboard(
                controller: _controller,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                keyColor: Theme.of(context).colorScheme.surface,
                keyTextColor: Theme.of(context).colorScheme.onSurface,
                onLanguageChange: () {},
              ),
          ],
        ),
      ),
    );
  }
}
