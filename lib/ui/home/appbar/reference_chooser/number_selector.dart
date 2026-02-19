import 'package:flutter/material.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_input_field.dart';

import 'swipeable_selector.dart';

class NumberSelector extends StatelessWidget {
  final TextEditingController controller;
  final int currentValue;
  final bool isActive;
  final FocusNode focusNode;
  final bool enableSwipe;
  final VoidCallback onTap;

  // Swipe callbacks
  final String? Function() onPeekNext;
  final VoidCallback onNextInvoked;
  final String? Function() onPeekPrevious;
  final VoidCallback onPreviousInvoked;
  final Function(KeyEvent) onKeyEvent;

  const NumberSelector({
    super.key,
    required this.controller,
    required this.currentValue,
    required this.isActive,
    required this.focusNode,
    required this.enableSwipe,
    required this.onTap,
    required this.onPeekNext,
    required this.onNextInvoked,
    required this.onPeekPrevious,
    required this.onPreviousInvoked,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return ReferenceInputField(
        text: controller.text,
        focusNode: focusNode,
        isActive: true,
        onTap: onTap,
        onKeyEvent: onKeyEvent,
      );
    }

    return SwipeableSelectorButton(
      label: currentValue.toString(),
      onTap: onTap,
      enableSwipe: enableSwipe,
      onPeekNext: onPeekNext,
      onNextInvoked: onNextInvoked,
      onPeekPrevious: onPeekPrevious,
      onPreviousInvoked: onPreviousInvoked,
    );
  }
}
