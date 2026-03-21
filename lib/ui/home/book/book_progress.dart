import 'package:flutter/material.dart';

class BookProgress extends StatelessWidget {
  final double progress;

  const BookProgress({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LinearProgressIndicator(
      value: progress,
      color: colors.primary,
      backgroundColor: colors.surfaceContainerHighest,
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
    );
  }
}
