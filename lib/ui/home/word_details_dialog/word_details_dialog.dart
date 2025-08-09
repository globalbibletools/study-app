import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/similar_verses/similar_verses_page.dart';
import 'package:studyapp/ui/home/word_details_dialog/dialog_manager.dart';

/// A dialog that displays detailed information about a single word.
class WordDetailsDialog extends StatefulWidget {
  const WordDetailsDialog({
    super.key,
    required this.wordId,
    required this.isRtl,
  });

  final int wordId;
  final bool isRtl;

  @override
  State<WordDetailsDialog> createState() => _WordDetailsDialogState();
}

class _WordDetailsDialogState extends State<WordDetailsDialog> {
  final manager = WordDetailsDialogManager();
  TextStyle? highlightStyle;
  TextStyle? defaultStyle;

  static const fontSize = 30.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    manager.init(locale, widget.wordId);
    highlightStyle = TextStyle(
      fontSize: fontSize * 0.6,
      color: Theme.of(context).colorScheme.primary,
    );
    defaultStyle = TextStyle(fontSize: fontSize * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final wordDetails = manager.wordDetails;
        if (wordDetails == null) return const SizedBox();
        return AlertDialog(
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHebrewGreekWord(wordDetails),
                  _buildGrammar(wordDetails),
                  const SizedBox(height: 16),
                  _buildSimilarVersesButton(context, wordDetails),
                  const SizedBox(height: 16),
                  _buildGloss(wordDetails),
                  ..._buildLexicon(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  FittedBox _buildHebrewGreekWord(WordDetails wordDetails) {
    return FittedBox(
      child: SelectableText(
        wordDetails.word,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: fontSize * 2),
      ),
    );
  }

  FittedBox _buildGrammar(WordDetails wordDetails) {
    return FittedBox(
      child: SelectableText.rich(_buildTappableGrammar(wordDetails.grammar)),
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
                    final expansion = manager.expandGrammar(grammar);
                    _showGrammarExpansionDialog(expansion);
                  },
          ),
        );
        return ''; // unused
      },
    );

    return TextSpan(children: spans);
  }

  void _showGrammarExpansionDialog(String grammarExpansion) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(grammarExpansion, style: defaultStyle),
          ),
        );
      },
    );
  }

  OutlinedButton _buildSimilarVersesButton(
    BuildContext context,
    WordDetails wordDetails,
  ) {
    return OutlinedButton(
      child: Text(
        AppLocalizations.of(context)!.similarVerses,
        style: defaultStyle,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SimilarVersesPage(
                  root: root,
                  strongsCode: wordDetails.strongsCode,
                  isRtl: widget.isRtl,
                ),
          ),
        );
      },
    );
  }

  String? get root {
    final meanings = manager.lexiconMeanings;
    if (meanings.isEmpty) return null;
    return meanings.first.lemma;
  }

  FittedBox _buildGloss(WordDetails wordDetails) {
    return FittedBox(
      child: SelectableText(
        wordDetails.gloss,
        textAlign: TextAlign.center,
        style: defaultStyle,
      ),
    );
  }

  List<Widget> _buildLexicon() {
    final rows = <Widget>[];
    final meanings = manager.lexiconMeanings;
    int oldLemmaId = 0;
    int meaningNumber = 0;
    for (final meaning in meanings) {
      if (meaning.lemmaId != oldLemmaId) {
        rows.add(
          Row(
            children: [
              SelectableText(
                meaning.lemma,
                style: TextStyle(fontSize: fontSize),
              ),
              SizedBox(width: 8),
              if (meaning.grammar != null)
                SelectableText('(${meaning.grammar})', style: defaultStyle),
            ],
          ),
        );
        rows.add(const SizedBox(height: 8));
        oldLemmaId = meaning.lemmaId;
        meaningNumber = 0;
      }
      meaningNumber++;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('$meaningNumber. ', style: defaultStyle),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(meaning.glosses, style: defaultStyle),
                  const SizedBox(height: 8),
                  if (meaning.definitionShort != null)
                    SelectableText(
                      meaning.definitionShort!,
                      style: defaultStyle,
                    ),
                  if (meaning.definitionShort != null)
                    const SizedBox(height: 8),
                  if (meaning.comments != null)
                    SelectableText(meaning.comments!, style: defaultStyle),
                  if (meaning.comments != null) const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }
}
