import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/keypad/numeric_keypad.dart';
import 'package:studyapp/ui/home/home_manager.dart';

class KeypadLayer extends StatelessWidget {
  const KeypadLayer({super.key, required this.manager});

  final HomeManager manager;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ValueListenableBuilder<ReferenceInputMode>(
        valueListenable: manager.inputModeNotifier,
        builder: (context, inputMode, _) {
          return AnimatedSlide(
            offset:
                (inputMode == ReferenceInputMode.chapter ||
                    inputMode == ReferenceInputMode.verse)
                ? Offset.zero
                : const Offset(0, 1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Material(
              elevation: 16,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ValueListenableBuilder<Set<int>>(
                valueListenable: manager.enabledDigitsNotifier,
                builder: (context, enabledDigits, _) {
                  return NumericKeypad(
                    isLastInput: inputMode == ReferenceInputMode.verse,
                    enabledDigits: enabledDigits,
                    // Forward events to Manager
                    onDigit: manager.handleDigit,
                    onBackspace: manager.handleBackspace,
                    onSubmit: manager.handleSubmit,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
