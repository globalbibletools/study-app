import 'package:material_ui/material_ui.dart';

class ProgressCircle extends StatelessWidget {
  static const double defaultSize = 64;

  const ProgressCircle({
    super.key,
    required this.percent,
    this.size = defaultSize,
    this.strokeWidth = 6,
    this.fontSize = 16,
  });

  final double percent;
  final double size;
  final double strokeWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedPercent = percent.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: normalizedPercent,
              strokeWidth: strokeWidth,
              strokeAlign: CircularProgressIndicator.strokeAlignInside,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${(normalizedPercent * 100).round()}%',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
