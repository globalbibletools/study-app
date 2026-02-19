import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReferenceInputField extends StatefulWidget {
  final String text;
  final FocusNode focusNode;
  final bool isActive;
  final VoidCallback onTap;
  final Function(KeyEvent) onKeyEvent;

  const ReferenceInputField({
    super.key,
    required this.text,
    required this.focusNode,
    required this.isActive,
    required this.onTap,
    required this.onKeyEvent,
  });

  @override
  State<ReferenceInputField> createState() => _ReferenceInputFieldState();
}

class _ReferenceInputFieldState extends State<ReferenceInputField>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Total blink cycle
    );

    if (widget.isActive) {
      _cursorController.repeat();
    }
  }

  @override
  void didUpdateWidget(ReferenceInputField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. Handle activation/deactivation
    if (widget.isActive && !oldWidget.isActive) {
      _cursorController.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _cursorController.stop();
    }

    // 2. Natural Reset: If the text changed, "reset" the blink
    // so the cursor is immediately visible while typing.
    if (widget.text != oldWidget.text && widget.isActive) {
      _cursorController.forward(from: 0.0);
      _cursorController.repeat();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isFocused = widget.isActive;
    final borderColor = isFocused ? colorScheme.primary : colorScheme.outline;
    final borderWidth = isFocused ? 2.5 : 1.0;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          widget.onKeyEvent(event);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40, // FIXED CONSTANT WIDTH
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                MainAxisAlignment.center, // Keep text + cursor centered
            children: [
              Text(
                widget.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isFocused
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  fontSize: 18,
                ),
              ),
              if (isFocused)
                AnimatedBuilder(
                  animation: _cursorController,
                  builder: (context, child) {
                    final bool showCursor = _cursorController.value < 0.5;
                    return Opacity(
                      opacity: showCursor ? 1.0 : 0.0,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 2,
                    height: 20,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
