import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom in-app keyboard for the Hebrew alphabet.
class HebrewKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onLanguageChange;
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
  /// mistakenly used in the middle of a word.
  ///
  /// For example:
  /// - "כספ" followed by a space becomes "כסף ".
  /// - "שלום" remains "שלום".
  /// - "מלך" remains "מלך".
  /// - Corrects "שלוםך" to "שלומך" by replacing the final Kaf.
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

    // Regex to find a final-form letter that is followed by another Hebrew letter.
    // This is an incorrect usage that needs to be corrected.
    // The `(?=...)` is a positive lookahead, which checks the character
    // after the match without including it in the match itself.
    final RegExp regularFormRegex = RegExp(
      r'[ךםןףץ](?=[\u0590-\u05FF])',
      unicode: true,
    );

    // Regex to find a regular-form letter that should be a final form.
    // This matches a letter that is NOT followed by another Hebrew letter.
    // This could be the end of the string, or followed by a space, punctuation, etc.
    // The `(?!...)` is a negative lookahead.
    final RegExp finalFormRegex = RegExp(
      r'[כמנפצ](?![\u0590-\u05FF])',
      unicode: true,
    );

    // --- Step 1: Correct any final letters that are now in the middle of a word.
    // e.g., if the user had "שלם" and then typed "ו", it becomes "שלםו".
    // This step will correct "שלםו" to "שלמו".
    String correctedText = text.replaceAllMapped(regularFormRegex, (match) {
      final matchedChar = match.group(0)!;
      return regularLetterMap[matchedChar]!;
    });

    // --- Step 2: Convert letters at the end of words to their final form.
    // e.g., if the text is "עכשיו אני כותב", this will change "כותב" to "כותב".
    // No, that's a bad example. Let's use "כספ" -> "כסף".
    correctedText = correctedText.replaceAllMapped(finalFormRegex, (match) {
      final matchedChar = match.group(0)!;
      return finalLetterMap[matchedChar]!;
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
                widget.onLanguageChange?.call();
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
