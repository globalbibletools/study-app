import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
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
  TextStyle? defaultBold;
  TextStyle? lexiconStyle;

  static const fontSize = 30.0;
  bool _isCopied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    manager.init(locale, widget.wordId);
    highlightStyle = TextStyle(
      fontSize: fontSize * 0.8,
      color: Theme.of(context).colorScheme.primary,
    );
    defaultStyle = TextStyle(fontSize: fontSize * 0.8);
    defaultBold = defaultStyle?.copyWith(fontWeight: FontWeight.bold);
    lexiconStyle = defaultStyle?.copyWith(
      color: Theme.of(
        context,
      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
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
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 24.0),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Stack(
              alignment: AlignmentDirectional.topCenter,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHebrewGreekWord(wordDetails),
                      _buildGrammar(wordDetails),
                      const SizedBox(height: 8),
                      _buildActionButtons(context, wordDetails),
                      const SizedBox(height: 16),
                      _buildGloss(wordDetails),
                      ..._buildLexicon(),
                    ],
                  ),
                ),
                _buildCloseButton(context),
              ],
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
            recognizer: TapGestureRecognizer()
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

  Widget _buildActionButtons(BuildContext context, WordDetails wordDetails) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Similar Verses Button
        IconButton(
          icon: Icon(Icons.list, color: iconColor),
          tooltip: AppLocalizations.of(context)!.similarVerses,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SimilarVersesPage(word: wordDetails),
              ),
            );
          },
        ),
        const SizedBox(width: 24),
        // Copy Button
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              _isCopied ? Icons.check : Icons.copy,
              key: ValueKey<bool>(_isCopied),
              color: _isCopied ? Colors.green : iconColor,
            ),
          ),
          tooltip: 'Copy word',
          onPressed: () => _handleCopy(wordDetails.word),
        ),
      ],
    );
  }

  Future<void> _handleCopy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    setState(() {
      _isCopied = true;
    });

    // Reset back to copy icon after 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _isCopied = false;
    });
  }

  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
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
                style: TextStyle(fontSize: fontSize * 1.2),
              ),
              SizedBox(width: 8),
              if (meaning.grammar != null)
                SelectableText('(${meaning.grammar})', style: lexiconStyle),
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
                  SelectableText(meaning.glosses, style: defaultBold),
                  const SizedBox(height: 8),
                  if (meaning.definitionShort != null)
                    SelectableText(
                      meaning.definitionShort!,
                      style: lexiconStyle,
                    ),
                  if (meaning.definitionShort != null)
                    const SizedBox(height: 8),
                  if (meaning.comments != null)
                    SelectableText(meaning.comments!, style: lexiconStyle),
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
