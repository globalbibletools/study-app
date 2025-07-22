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

    // Replace the selected text (if any) with the new character.
    final newText = currentText.replaceRange(
      selection.start,
      selection.end,
      text,
    );

    // The new cursor position should be after the inserted text.
    // For RTL text (like Hebrew), the TextField using this controller will
    // correctly place the cursor visually to the left of the new character.
    final newCursorOffset = selection.start + text.length;

    // Update the controller's value with the new text and selection.
    // Using `copyWith` on `value` is the recommended way to update
    // both text and selection atomically, preventing potential issues.
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
      composing: TextRange.empty, // Clear any composing text
    );
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
        return; // Nothing to delete at the beginning.
      }
      // Create the new text by removing the character before the cursor.
      final newText = text.substring(0, start - 1) + text.substring(start);
      // Update the controller with the new text and move the cursor back.
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start - 1),
        composing: TextRange.empty,
      );
    } else {
      // A range of text is selected, so delete the selection.
      // Create the new text by removing the selected range.
      final newText = text.replaceRange(start, end, '');
      // Update the controller with the new text and place the cursor at the
      // beginning of the original selection.
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
    }
  }

  // --- BUILD METHODS ---

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
        // Backspace Key with Long-Press Gesture Detector
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.keyColor.withOpacity(0.8),
                foregroundColor: widget.keyTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              onPressed: _onBackspacePressed,
              child: Icon(
                Icons.backspace_outlined,
                size: 24,
                color: widget.keyTextColor,
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
                backgroundColor: widget.keyColor.withOpacity(0.8),
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
