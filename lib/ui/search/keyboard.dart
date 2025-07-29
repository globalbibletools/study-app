import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom in-app keyboard for Biblical Hebrew and Greek alphabets.
class HebrewGreekKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final void Function(TextDirection) onLanguageChange;
  final String Function(String) fixFinalForms;
  final bool isHebrew;
  final Color backgroundColor;
  final Color keyColor;
  final Color keyTextColor;

  /// A notifier that the keyboard listens to for candidate word updates.
  /// The parent widget holds and updates this notifier. When the notifier's
  /// value changes, the keyboard will update the candidate list internally.
  final ValueNotifier<List<String>>? candidatesNotifier;

  /// A callback that is triggered when a candidate word is tapped.
  final void Function(String candidate)? onCandidateTapped;

  /// The search button was pressed
  final VoidCallback onSearch;

  const HebrewGreekKeyboard({
    super.key,
    required this.controller,
    required this.onLanguageChange,
    required this.fixFinalForms,
    required this.isHebrew,
    this.backgroundColor = const Color(0xFFD1D5DB),
    this.keyColor = Colors.white,
    this.keyTextColor = Colors.black,
    this.candidatesNotifier,
    this.onCandidateTapped,
    required this.onSearch,
  });

  @override
  State<HebrewGreekKeyboard> createState() => _HebrewGreekKeyboardState();
}

class _HebrewGreekKeyboardState extends State<HebrewGreekKeyboard> {
  // bool _isHebrew = true;

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
    // The new cursor position will be after the inserted text.
    final newCursorOffset = selection.start + text.length;

    String processedText = widget.fixFinalForms(newText);

    controller.value = controller.value.copyWith(
      text: processedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
      composing: TextRange.empty,
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
    return Container(
      width: double.infinity,
      color: widget.backgroundColor,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCandidateList(),
          _buildKeyboardLayout(),
          const SizedBox(height: 4),
          _buildActionRow(),
        ],
      ),
    );
  }

  /// Builds the top row for word candidates using a ValueListenableBuilder.
  /// This widget automatically rebuilds ONLY the candidate row when the notifier's value changes.
  Widget _buildCandidateList() {
    const candidateRowHeight = 50.0;

    // If no notifier is provided, just return a fixed-size empty box
    // to prevent the keyboard from changing height.
    if (widget.candidatesNotifier == null) {
      return const SizedBox(height: candidateRowHeight);
    }

    return ValueListenableBuilder<List<String>>(
      // The builder listens to this notifier.
      valueListenable: widget.candidatesNotifier!,
      // The builder function is called whenever the notifier's value changes.
      builder: (context, candidates, child) {
        // `candidates` is the latest List<String> from the notifier.

        final direction =
            widget.isHebrew ? TextDirection.rtl : TextDirection.ltr;

        Widget buildCandidateButton(String candidate) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: widget.backgroundColor.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onCandidateTapped?.call(candidate);
                },
                child: FittedBox(
                  child: Text(
                    candidate,
                    style: TextStyle(
                      color: widget.keyTextColor,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'sbl',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          );
        }

        List<Widget> slots = [
          const Expanded(child: SizedBox()), // Slot 1 (Start)
          const Expanded(child: SizedBox()), // Slot 2 (Middle)
          const Expanded(child: SizedBox()), // Slot 3 (End)
        ];

        final displayCandidates = candidates.take(3).toList();

        if (displayCandidates.length == 1) {
          slots[1] = buildCandidateButton(displayCandidates[0]);
        } else if (displayCandidates.length == 2) {
          slots[0] = buildCandidateButton(displayCandidates[0]);
          slots[1] = buildCandidateButton(displayCandidates[1]);
        } else if (displayCandidates.length >= 3) {
          slots[0] = buildCandidateButton(displayCandidates[0]);
          slots[1] = buildCandidateButton(displayCandidates[1]);
          slots[2] = buildCandidateButton(displayCandidates[2]);
        }

        // Return the row widget, which will be rebuilt on each update.
        return Directionality(
          textDirection: direction,
          child: SizedBox(
            height: candidateRowHeight,
            child: Row(children: slots),
          ),
        );
      },
    );
  }

  /// Builds the appropriate keyboard layout based on the current language.
  Widget _buildKeyboardLayout() {
    if (widget.isHebrew) {
      const List<String> row1 = ['א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח'];
      const List<String> row2 = ['ט', 'י', 'כ', 'ל', 'מ', 'נ', 'ס'];
      const List<String> row3 = ['ע', 'פ', 'צ', 'ק', 'ר', 'ש', 'ת'];

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLetterRow(row1, TextDirection.rtl),
          const SizedBox(height: 4),
          _buildLetterRow(row2, TextDirection.rtl),
          const SizedBox(height: 4),
          _buildLetterRow(row3, TextDirection.rtl),
        ],
      );
    } else {
      // Greek Keyboard Layout
      const List<String> row1 = ['α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ'];
      const List<String> row2 = ['ι', 'κ', 'λ', 'μ', 'ν', 'ξ', 'ο', 'π'];
      const List<String> row3 = ['ρ', 'σ', 'τ', 'υ', 'φ', 'χ', 'ψ', 'ω'];

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLetterRow(row1, TextDirection.ltr),
          const SizedBox(height: 4),
          _buildLetterRow(row2, TextDirection.ltr),
          const SizedBox(height: 4),
          _buildLetterRow(row3, TextDirection.ltr),
        ],
      );
    }
  }

  /// Builds a single row of letter keys.
  /// The [direction] parameter ensures the keys are laid out correctly.
  Widget _buildLetterRow(List<String> letters, TextDirection direction) {
    return Row(
      textDirection: direction,
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

  /// Builds the bottom action row (backspace, space, language switch).
  Widget _buildActionRow() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Language Change Key
          Expanded(
            flex: 2,
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
                  final isHebrew = !widget.isHebrew;
                  final direction =
                      isHebrew ? TextDirection.rtl : TextDirection.ltr;
                  widget.onLanguageChange.call(direction);
                },
                child: Icon(
                  Icons.language,
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
            flex: 2,
          ),
          // Backspace
          Expanded(
            flex: 2,
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
                child: Directionality(
                  textDirection:
                      widget.isHebrew ? TextDirection.rtl : TextDirection.ltr,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: widget.keyTextColor,
                  ),
                ),
              ),
            ),
          ),
          // Search
          Expanded(
            flex: 2,
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
                  widget.onSearch();
                },
                child: Icon(Icons.search, size: 24, color: widget.keyTextColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
