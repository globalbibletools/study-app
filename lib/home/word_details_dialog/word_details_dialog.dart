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
  final wordDetailsNotifier = ValueNotifier<WordDetails?>(null);
  final manager = WordDetailsDialogManager();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lookupWordDetails();
  }

  Future<void> _lookupWordDetails() async {
    final locale = Localizations.localeOf(context);
    final wordDetails = await manager.getWordDetails(locale, widget.wordId);
    wordDetailsNotifier.value = wordDetails;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WordDetails?>(
      valueListenable: wordDetailsNotifier,
      builder: (context, wordDetails, child) {
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
                TextButton(
                  child: Text(
                    wordDetails.grammar,
                    style: TextStyle(
                      fontFamily: 'sbl',
                      fontSize: widget.fontSize * 0.7,
                    ),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(height: 16),
                SelectableText(
                  wordDetails.gloss,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'sbl',
                    fontSize: widget.fontSize * 0.7,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  child: Text(
                    wordDetails.strongsCode,
                    style: TextStyle(
                      fontFamily: 'sbl',
                      fontSize: widget.fontSize * 0.7,
                    ),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
