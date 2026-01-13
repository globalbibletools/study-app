import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/home/common/zoom_wrapper.dart';
import 'package:studyapp/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
import 'package:studyapp/ui/home/word_details_dialog/dialog_manager.dart';

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
  bool _isCopied = false;
  static const baseFontSize = 30.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    manager.init(locale, widget.wordId);
    // Note: Styles are now defined inside the build method to react to scaling
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, child) {
        final wordDetails = manager.wordDetails;
        if (wordDetails == null) return const SizedBox();

        // Use ZoomWrapper here
        return ZoomWrapper(
          initialScale: manager.initialFontScale,
          onScaleChanged: manager.saveFontScale,
          builder: (context, scale) {
            // --- DEFINE STYLES BASED ON SCALE ---
            // 1. Scalable Text Styles (Grammar, Gloss, Lexicon)
            final scalableSize = baseFontSize * 0.8 * scale;

            final highlightStyle = TextStyle(
              fontSize: scalableSize,
              color: Theme.of(context).colorScheme.primary,
            );
            final defaultStyle = TextStyle(fontSize: scalableSize);
            final defaultBold = defaultStyle.copyWith(
              fontWeight: FontWeight.bold,
            );
            final lexiconStyle = defaultStyle.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
            );

            // 2. Fixed Text Styles (Main Hebrew Word)
            // We do NOT multiply this by 'scale' so it stays the same size
            final fixedHeaderStyle = TextStyle(fontSize: baseFontSize * 2);

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
                          _buildHebrewGreekWord(wordDetails, fixedHeaderStyle),
                          _buildGrammar(
                            wordDetails,
                            defaultStyle,
                            highlightStyle,
                          ),
                          const SizedBox(height: 8),
                          _buildActionButtons(context, wordDetails),
                          const SizedBox(height: 8),
                          _buildGloss(wordDetails, defaultStyle),
                          ..._buildLexicon(
                            defaultStyle,
                            defaultBold,
                            lexiconStyle,
                            scalableSize,
                          ),
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
      },
    );
  }

  // Pass style as parameter
  FittedBox _buildHebrewGreekWord(WordDetails wordDetails, TextStyle style) {
    return FittedBox(
      child: SelectableText(
        wordDetails.word,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  // Pass styles as parameters
  FittedBox _buildGrammar(
    WordDetails wordDetails,
    TextStyle defaultStyle,
    TextStyle highlightStyle,
  ) {
    return FittedBox(
      child: SelectableText.rich(
        _buildTappableGrammar(
          wordDetails.grammar,
          defaultStyle,
          highlightStyle,
        ),
      ),
    );
  }

  TextSpan _buildTappableGrammar(
    String grammar,
    TextStyle defaultStyle,
    TextStyle highlightStyle,
  ) {
    final List<TextSpan> spans = [];
    final separatorPattern = RegExp(r'[|,]');

    grammar.splitMapJoin(
      separatorPattern,
      onMatch: (Match match) {
        final separator = match.group(0)!;
        spans.add(TextSpan(text: separator, style: defaultStyle));
        return '';
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
                // We recreate the dialog style locally since it's a new dialog
                final dialogStyle = defaultStyle.copyWith(
                  fontSize: baseFontSize * 0.8,
                );
                _showGrammarExpansionDialog(expansion, dialogStyle);
              },
          ),
        );
        return '';
      },
    );

    return TextSpan(children: spans);
  }

  void _showGrammarExpansionDialog(String grammarExpansion, TextStyle style) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(grammarExpansion, style: style),
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

  FittedBox _buildGloss(WordDetails wordDetails, TextStyle style) {
    return FittedBox(
      child: SelectableText(
        wordDetails.gloss,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }

  List<Widget> _buildLexicon(
    TextStyle defaultStyle,
    TextStyle defaultBold,
    TextStyle lexiconStyle,
    double scalableFontSize,
  ) {
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
                // Lemma is slightly larger than body
                style: TextStyle(fontSize: scalableFontSize * 1.5),
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
