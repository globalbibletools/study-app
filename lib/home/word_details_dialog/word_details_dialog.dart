import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/home/word_details_dialog/dialog_manager.dart';

/// A dialog that displays detailed information about a single word.
class WordDetailsDialog extends StatefulWidget {
  final int wordId;
  final double fontSize;

  const WordDetailsDialog({
    super.key,
    required this.wordId,
    required this.fontSize,
  });

  @override
  State<WordDetailsDialog> createState() => _WordDetailsDialogState();
}

class _WordDetailsDialogState extends State<WordDetailsDialog> {
  final manager = WordDetailsDialogManager();
  TextStyle? highlightStyle;
  TextStyle? defaultStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    manager.init(locale, widget.wordId);
    // _lookupWordDetails();
    highlightStyle = TextStyle(
      fontFamily: 'sbl',
      fontSize: widget.fontSize * 0.7,
      color: Theme.of(context).colorScheme.primary,
    );
    defaultStyle = TextStyle(
      fontFamily: 'sbl',
      fontSize: widget.fontSize * 0.7,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final wordDetails = manager.wordDetails;
        if (wordDetails == null) return const SizedBox();
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  wordDetails.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'sbl',
                    fontSize: widget.fontSize * 2,
                  ),
                ),
                SelectableText.rich(
                  _buildTappableGrammar(wordDetails.grammar),
                  // style: defaultStyle,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  wordDetails.gloss,
                  textAlign: TextAlign.center,
                  style: defaultStyle,
                ),
                const SizedBox(height: 16),
                TextButton(
                  child: Text(wordDetails.strongsCode, style: defaultStyle),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  TextSpan _buildTappableGrammar(String grammar) {
    final List<TextSpan> spans = [];
    final separatorPattern = RegExp(r'[|,]');

    grammar.splitMapJoin(
      separatorPattern,
      onMatch: (Match match) {
        final separator = match.group(0)!; // "," or "|"
        spans.add(TextSpan(text: separator, style: defaultStyle));
        return ''; // unused
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isEmpty) return '';
        spans.add(
          TextSpan(
            text: nonMatch,
            style: highlightStyle,
            recognizer:
                TapGestureRecognizer()
                  ..onTap = () {
                    final grammar = nonMatch.trim();
                    print('Recognizer Tapped: "$grammar"');
                  },
          ),
        );
        return ''; // unused
      },
    );

    return TextSpan(children: spans);
  }
}
