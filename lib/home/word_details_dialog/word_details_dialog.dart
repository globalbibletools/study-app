import 'dart:async';

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
  final _dialogKey = GlobalKey();
  Rect? _grammarPanelRect;
  Timer? _grammarPopupTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    manager.init(locale, widget.wordId);
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
  void dispose() {
    _grammarPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final wordDetails = manager.wordDetails;
        if (wordDetails == null) return const SizedBox();
        final renderBox =
            _dialogKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          _grammarPanelRect =
              renderBox.localToGlobal(Offset.zero) & renderBox.size;
        }
        return Stack(
          children: [
            AlertDialog(
              content: SingleChildScrollView(
                key: _dialogKey,
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
            ),

            if (_grammarPanelRect != null && manager.grammarExpansion != null)
              _buildGrammarExpansionPanel(),
          ],
        );
      },
    );
  }

  Widget _buildGrammarExpansionPanel() {
    final screenSize = MediaQuery.sizeOf(context);
    final bottomPosition = screenSize.height - _grammarPanelRect!.top + 32.0;
    final padding = 20.0;
    return Positioned(
      left: _grammarPanelRect!.left - padding,
      width: _grammarPanelRect!.width + 2 * padding,
      bottom: bottomPosition,
      child: Material(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            color: Theme.of(context).colorScheme.inverseSurface,
            child: Text(
              manager.grammarExpansion ?? 'No details found.',
              textAlign: TextAlign.center,
              style: defaultStyle!.copyWith(
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
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
                    _grammarPopupTimer?.cancel();
                    final grammar = nonMatch.trim();
                    manager.showGrammar(grammar);
                    _grammarPopupTimer = Timer(const Duration(seconds: 3), () {
                      manager.hideGrammar();
                    });
                  },
          ),
        );
        return ''; // unused
      },
    );

    return TextSpan(children: spans);
  }
}
