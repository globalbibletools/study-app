import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/resource_language_text_direction.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'package:gbt/ui/common/word_popup.dart';

class ParallelVerseData {
  final String bibleId;
  final String badge;
  final String text;
  final TextDirection textDirection;

  const ParallelVerseData({
    required this.bibleId,
    required this.badge,
    required this.text,
    this.textDirection = TextDirection.ltr,
  });
}

class VerseListItem extends StatefulWidget {
  const VerseListItem({
    super.key,
    this.verseContentFuture,
    this.wordsFuture,
    this.highlightPredicate,
    this.highlightColor,
    this.fontSize = 20.0,
    required this.formattedReference,
    required this.textDirection,
    this.onReferenceTapped,
    this.parallelVerses,
  }) : assert(
         verseContentFuture != null || wordsFuture != null,
         'Either verseContentFuture or wordsFuture must be provided.',
       );

  final Future<TextSpan>? verseContentFuture;
  final Future<List<HebrewGreekWord>>? wordsFuture;
  final bool Function(HebrewGreekWord word)? highlightPredicate;
  final Color? highlightColor;
  final double fontSize;
  final String formattedReference;
  final TextDirection textDirection;
  final VoidCallback? onReferenceTapped;
  final List<ParallelVerseData>? parallelVerses;

  @override
  State<VerseListItem> createState() => _VerseListItemState();
}

class _VerseListItemState extends State<VerseListItem> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  Future<void> _onWordTapped(
    HebrewGreekWord word,
    Offset globalPosition,
  ) async {
    final gloss = await getIt<GlossService>().glossForId(
      wordId: word.id,
      onDatabaseMissing: (langCode) async {
        if (!mounted) return;
        await ResourceUIHelper.ensureResource(
          context,
          ResourceType.gloss,
          langCode,
        );
      },
    );
    if (!mounted || gloss == null || gloss.gloss.isEmpty) return;

    WordPopup.show(
      context: context,
      anchorPosition: globalPosition,
      popup: WordPopup(
        text: gloss.gloss,
        isAiGenerated: gloss.isAiGenerated,
        textDirection: gloss.textDirection.toTextDirection,
      ),
    );
  }

  TextSpan _buildSpansFromWords(
    List<HebrewGreekWord> words,
    BuildContext context,
  ) {
    _clearRecognizers();
    const maqaph = '־';
    final defaultHighlightColor = Theme.of(context).colorScheme.primary;
    final spans = <TextSpan>[];

    for (final word in words) {
      final isHighlighted = widget.highlightPredicate?.call(word) ?? false;
      final color = isHighlighted
          ? (widget.highlightColor ?? defaultHighlightColor)
          : null;
      final text = word.text.endsWith(maqaph) ? word.text : '${word.text} ';

      final recognizer = TapGestureRecognizer()
        ..onTapUp = (details) {
          _onWordTapped(word, details.globalPosition);
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: widget.fontSize),
          recognizer: recognizer,
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildListTile(
    BuildContext context,
    Widget titleWidget,
    TextSpan verseSpan,
  ) {
    return ListTile(
      title: titleWidget,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(verseSpan, textDirection: widget.textDirection),
          if (widget.parallelVerses != null &&
              widget.parallelVerses!.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            for (final parallel in widget.parallelVerses!)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Directionality(
                  textDirection: parallel.textDirection,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          parallel.badge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          parallel.text,
                          textDirection: parallel.textDirection,
                          textAlign: parallel.textDirection == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget titleWidget = Text(
      widget.formattedReference,
      style: TextStyle(
        color: widget.onReferenceTapped != null
            ? Theme.of(context).colorScheme.primary
            : Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        fontWeight: widget.onReferenceTapped != null
            ? FontWeight.w600
            : FontWeight.normal,
      ),
    );

    if (widget.onReferenceTapped != null) {
      titleWidget = InkWell(
        onTap: widget.onReferenceTapped,
        borderRadius: BorderRadius.circular(4.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              titleWidget,
              const SizedBox(width: 4.0),
              Icon(
                Icons.arrow_outward,
                size: 14.0,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.wordsFuture != null) {
      return FutureBuilder<List<HebrewGreekWord>>(
        future: widget.wordsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final l10n = AppLocalizations.of(context)!;
            return ListTile(
              title: titleWidget,
              subtitle: Text(l10n.errorLoadingVerse(snapshot.error.toString())),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            final words = snapshot.data ?? [];
            final verseSpan = _buildSpansFromWords(words, context);
            return _buildListTile(context, titleWidget, verseSpan);
          }
          return const SizedBox(height: 75);
        },
      );
    }

    return FutureBuilder<TextSpan>(
      future: widget.verseContentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final l10n = AppLocalizations.of(context)!;
          return ListTile(
            title: titleWidget,
            subtitle: Text(l10n.errorLoadingVerse(snapshot.error.toString())),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          final verseSpan = snapshot.data!;
          return _buildListTile(context, titleWidget, verseSpan);
        }
        return const SizedBox(height: 75);
      },
    );
  }
}
