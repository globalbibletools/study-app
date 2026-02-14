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
          _buildRow([1, 2, 3]),
          const SizedBox(height: 16),
          _buildRow([4, 5, 6]),
          const SizedBox(height: 16),
          _buildRow([7, 8, 9]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                color: Theme.of(context).colorScheme.error,
              ),
              _buildDigitButton(0),
              _buildActionButton(
                icon: isLastInput ? Icons.check : Icons.arrow_forward,
                onTap: onSubmit,
                color: Theme.of(context).colorScheme.primary,
                isFilled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(int digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => onDigit(digit),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              digit.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isFilled = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isFilled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: isFilled ? null : Border.all(color: color),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isFilled ? Colors.white : color,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
