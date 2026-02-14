import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(int) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool isLastInput;

  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.isLastInput = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(16),
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
              ),
              _buildKey(context, digit: 0, onTap: () => onDigit(0)),
              _buildKey(
                context,
                icon: isLastInput ? Icons.check : Icons.arrow_forward,
                onTap: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _buildKey(context, digit: d, onTap: () => onDigit(d)))
          .toList(),
    );
  }

  Widget _buildKey(
    BuildContext context, {
    int? digit,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          shape: (icon == null)
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                )
              : null,
          child: InkWell(
            onTap: onTap,
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
                            color: colorScheme.onSurface,
                          ) ??
                          TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    )
                  : Icon(icon, size: 24, color: colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
