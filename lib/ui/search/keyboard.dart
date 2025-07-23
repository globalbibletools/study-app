import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom in-app keyboard for the Hebrew alphabet.
class HebrewKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final void Function(TextDirection)? onLanguageChange;
  final Color backgroundColor;
  final Color keyColor;
  final Color keyTextColor;

  const HebrewKeyboard({
    super.key,
    required this.controller,
    this.onLanguageChange,
    this.backgroundColor = const Color(0xFFD1D5DB),
    this.keyColor = Colors.white,
    this.keyTextColor = Colors.black,
  });

  @override
  State<HebrewKeyboard> createState() => _HebrewKeyboardState();
}

class _HebrewKeyboardState extends State<HebrewKeyboard> {
  bool _isHebrew = true;

  /// Handles the press of a standard letter or space key.
  /// This method atomically updates the controller's text and selection.
  void _onKeyPressed(String text) {
    HapticFeedback.lightImpact();

    final controller = widget.controller;
    final currentText = controller.text;
    final selection = controller.selection;

    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    final newCursorOffset = selection.start + text.length;

    final replacedText = _replaceWithFinalLetterForms(newText);

    controller.value = controller.value.copyWith(
      text: replacedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
      composing: TextRange.empty,
    );
  }

  /// Automatically replaces Hebrew letters with their final-form counterparts
  /// (sofit) at the end of words, and corrects final-form letters that are
  /// mistakenly used in the middle of a word. Letters in isolation stay in regular form.
  String _replaceWithFinalLetterForms(String text) {
    // Mapping of regular letters to their final forms.
    const Map<String, String> finalLetterMap = {
      'כ': 'ך', // Kaf -> Final Kaf
      'מ': 'ם', // Mem -> Final Mem
      'נ': 'ן', // Nun -> Final Nun
      'פ': 'ף', // Pe -> Final Pe
      'צ': 'ץ', // Tsadi -> Final Tsadi
    };

    // Mapping of final-form letters back to their regular forms.
    const Map<String, String> regularLetterMap = {
      'ך': 'כ', // Final Kaf -> Kaf
      'ם': 'מ', // Final Mem -> Mem
      'ן': 'נ', // Final Nun -> Nun
      'ף': 'פ', // Final Pe -> Pe
      'ץ': 'צ', // Final Tsadi -> Tsadi
    };

    // Regex to find a final-form letter that is followed by another Hebrew
    // letter (i.e., in the middle of a word).
    final RegExp regularFormRegex = RegExp(
      r'[ךםןףץ](?=[\u0590-\u05FF])',
      unicode: true,
    );

    // Split the text into words using space and punctuation boundaries.
    final wordRegex = RegExp(r'\b([\u0590-\u05FF]+)\b', unicode: true);
    String correctedText = text;

    correctedText = correctedText.replaceAllMapped(wordRegex, (match) {
      final word = match.group(1)!;

      // Return early if the word is a single Hebrew letter: keep it in regular form
      if (word.length == 1 && finalLetterMap.containsKey(word)) {
        return word; // no change
      }

      String newWord = word;

      // Step 1: Replace any incorrect final-forms used in the middle of the word
      newWord = newWord.replaceAllMapped(regularFormRegex, (m) {
        final ch = m.group(0)!;
        return regularLetterMap[ch]!;
      });

      // Step 2: Replace regular-form letters at the end with their final form
      final lastChar = newWord[newWord.length - 1];
      if (finalLetterMap.containsKey(lastChar)) {
        newWord =
            newWord.substring(0, newWord.length - 1) +
            finalLetterMap[lastChar]!;
      }

      return newWord;
    });

    return correctedText;
  }

  /// Handles a single backspace press, correctly managing cursor position
  /// and selected text.
  void _onBackspacePressed() {
    HapticFeedback.lightImpact();

    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (selection.isCollapsed) {
      // No text is selected, delete the character before the cursor.
      if (start == 0) {
        return;
      }
      final newText = text.substring(0, start - 1) + text.substring(start);
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
        composing: TextRange.empty,
      );
    } else {
      // A range of text is selected, so delete the selection.
      final newText = text.replaceRange(start, end, '');
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const List<String> row1 = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח'];
    // const List<String> row2 = ['ט', 'י', 'כ', 'ך', 'ל', 'מ', 'ם', 'נ', 'ן'];
    const List<String> row2 = ['ט', 'י', 'כ', 'ל', 'מ', 'נ', 'ס'];
    const List<String> row3 = ['ע', 'פ', 'צ', 'ק', 'ר', 'ש', 'ת'];

    return Container(
      width: double.infinity,
      color: widget.backgroundColor,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLetterRow(row1),
          const SizedBox(height: 4),
          _buildLetterRow(row2),
          const SizedBox(height: 4),
          _buildLetterRow(row3),
          const SizedBox(height: 4),
          _buildActionRow(),
        ],
      ),
    );
  }

  Widget _buildLetterRow(List<String> letters) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children:
          letters
              .map(
                (letter) => _KeyboardKey(
                  text: letter,
                  onKeyPressed: () => _onKeyPressed(letter),
                  keyColor: widget.keyColor,
                  textColor: widget.keyTextColor,
                ),
              )
              .toList(),
    );
  }

  Widget _buildActionRow() {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Backspace
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.keyColor,
                foregroundColor: widget.keyTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              onPressed: _onBackspacePressed,
              child: Transform.scale(
                scaleX: -1,
                child: Icon(
                  Icons.backspace_outlined,
                  size: 24,
                  color: widget.keyTextColor,
                ),
              ),
            ),
          ),
        ),
        // Space Key
        _KeyboardKey(
          text: ' ',
          onKeyPressed: () => _onKeyPressed(' '),
          keyColor: widget.keyColor,
          textColor: widget.keyTextColor,
          flex: 2, // Make spacebar wider
        ),
        // Language Change Key
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.keyColor,
                foregroundColor: widget.keyTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _isHebrew != _isHebrew;
                final direction =
                    _isHebrew ? TextDirection.rtl : TextDirection.ltr;
                widget.onLanguageChange?.call(direction);
              },
              child: Icon(Icons.language, size: 24, color: widget.keyTextColor),
            ),
          ),
        ),
      ],
    );
  }
}

// A private class for the individual keys to reduce code duplication.
class _KeyboardKey extends StatelessWidget {
  final String text;
  final VoidCallback onKeyPressed;
  final Color keyColor;
  final Color textColor;
  final int flex;

  const _KeyboardKey({
    required this.text,
    required this.onKeyPressed,
    this.keyColor = Colors.white,
    this.textColor = Colors.black,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: keyColor,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
          onPressed: onKeyPressed,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'sbl',
            ),
          ),
        ),
      ),
    );
  }
}
