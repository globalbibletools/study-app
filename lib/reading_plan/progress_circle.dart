import 'package:material_ui/material_ui.dart';

class ProgressCircle extends StatelessWidget {
  static const double defaultSize = 64;

  const ProgressCircle({
    super.key,
    required this.value,
    required this.percent,
    this.size = defaultSize,
    this.strokeWidth = 6,
    this.fontSize = 16,
  });

  final double value;
  final int percent;
  final double size;
  final double strokeWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              value: value.clamp(0.0, 1.0).toDouble(),
              strokeWidth: strokeWidth,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$percent%',
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
