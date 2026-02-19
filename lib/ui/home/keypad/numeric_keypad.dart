import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(int) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool isLastInput;
  final Set<int> enabledDigits;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.isLastInput = false,
    this.enabledDigits = const {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      excluding: true,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRow(context, [1, 2, 3]),
                  const SizedBox(height: 8),
                  _buildRow(context, [4, 5, 6]),
                  const SizedBox(height: 8),
                  _buildRow(context, [7, 8, 9]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKey(
                        context,
                        icon: Icons.backspace_outlined,
                        onTap: onBackspace,
                        isEnabled: true,
                      ),
                      _buildKey(
                        context,
                        digit: 0,
                        onTap: () => onDigit(0),
                        isEnabled: enabledDigits.contains(0),
                      ),
                      _buildKey(
                        context,
                        icon: isLastInput ? Icons.check : Icons.arrow_forward,
                        onTap: onSubmit,
                        isEnabled: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (d) => _buildKey(
              context,
              digit: d,
              onTap: () => onDigit(d),
              isEnabled: enabledDigits.contains(d),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKey(
    BuildContext context, {
    int? digit,
    IconData? icon,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Visual styling for disabled state
    final Color textColor = isEnabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.3);

    final Color borderColor = isEnabled
        ? colorScheme.onSurface.withValues(alpha: 0.5)
        : colorScheme.onSurface.withValues(alpha: 0.1);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          shape: (icon == null)
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor),
                )
              : null,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              child: digit != null
                  ? Text(
                      digit.toString(),
                      style:
                          theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ) ??
                          TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                    )
                  : Icon(icon, size: 24, color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
