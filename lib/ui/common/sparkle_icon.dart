import 'package:flutter/widgets.dart';

class SparkleIcon {
  SparkleIcon._();

  static const double _viewBoxSize = 512.0;
  static Path? _path;

  static Path get path => _path ??= _buildPath();

  static void paint(Canvas canvas, Rect rect, Color color) {
    if (rect.width <= 0 || rect.height <= 0) return;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / _viewBoxSize, rect.height / _viewBoxSize);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  static Path _buildPath() {
    return Path()
      ..moveTo(208, 512)
      ..arcToPoint(
        const Offset(184.66, 496),
        radius: const Radius.circular(24.84),
        clockwise: true,
      )
      ..lineTo(144.82, 392.4)
      ..arcToPoint(
        const Offset(135.63, 383.21),
        radius: const Radius.circular(16.06),
        clockwise: false,
      )
      ..lineTo(32, 343.34)
      ..arcToPoint(
        const Offset(32, 296.66),
        radius: const Radius.circular(25),
        clockwise: true,
      )
      ..lineTo(135.6, 256.82)
      ..arcToPoint(
        const Offset(144.79, 247.63),
        radius: const Radius.circular(16.06),
        clockwise: false,
      )
      ..lineTo(184.66, 144)
      ..arcToPoint(
        const Offset(231.34, 144),
        radius: const Radius.circular(25),
        clockwise: true,
      )
      ..lineTo(271.18, 247.6)
      ..arcToPoint(
        const Offset(280.37, 256.79),
        radius: const Radius.circular(16.06),
        clockwise: false,
      )
      ..lineTo(383.37, 296.42)
      ..arcToPoint(
        const Offset(400, 320.52),
        radius: const Radius.circular(25.49),
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(384, 343.34),
        radius: const Radius.circular(24.82),
        clockwise: true,
      )
      ..lineTo(280.4, 383.18)
      ..arcToPoint(
        const Offset(271.21, 392.37),
        radius: const Radius.circular(16.06),
        clockwise: false,
      )
      ..lineTo(231.34, 496)
      ..arcToPoint(
        const Offset(208, 512),
        radius: const Radius.circular(24.84),
        clockwise: true,
      )
      ..close()
      ..moveTo(274.85, 257.16)
      ..lineTo(274.85, 257.16)
      ..close()
      ..moveTo(88, 176)
      ..arcToPoint(
        const Offset(74.31, 166.6),
        radius: const Radius.circular(14.67),
        clockwise: true,
      )
      ..lineTo(57.45, 122.76)
      ..arcToPoint(
        const Offset(53.24, 118.55),
        radius: const Radius.circular(7.28),
        clockwise: false,
      )
      ..lineTo(9.4, 101.69)
      ..arcToPoint(
        const Offset(9.4, 74.31),
        radius: const Radius.circular(14.67),
        clockwise: true,
      )
      ..lineTo(53.24, 57.45)
      ..arcToPoint(
        const Offset(57.45, 53.24),
        radius: const Radius.circular(7.31),
        clockwise: false,
      )
      ..lineTo(74.16, 9.79)
      ..arcToPoint(
        const Offset(86.23, 0.11),
        radius: const Radius.circular(15),
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(101.69, 9.4),
        radius: const Radius.circular(14.67),
        clockwise: true,
      )
      ..lineTo(118.55, 53.24)
      ..arcToPoint(
        const Offset(122.76, 57.45),
        radius: const Radius.circular(7.31),
        clockwise: false,
      )
      ..lineTo(166.6, 74.31)
      ..arcToPoint(
        const Offset(166.6, 101.69),
        radius: const Radius.circular(14.67),
        clockwise: true,
      )
      ..lineTo(122.76, 118.55)
      ..arcToPoint(
        const Offset(118.55, 122.76),
        radius: const Radius.circular(7.28),
        clockwise: false,
      )
      ..lineTo(101.69, 166.6)
      ..arcToPoint(
        const Offset(88, 176),
        radius: const Radius.circular(14.67),
        clockwise: true,
      )
      ..close()
      ..moveTo(400, 256)
      ..arcToPoint(
        const Offset(385.07, 245.74),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..lineTo(362.23, 186.37)
      ..arcToPoint(
        const Offset(357.63, 181.77),
        radius: const Radius.circular(8),
        clockwise: false,
      )
      ..lineTo(298.26, 158.93)
      ..arcToPoint(
        const Offset(298.26, 129.07),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..lineTo(357.63, 106.23)
      ..arcToPoint(
        const Offset(362.23, 101.63),
        radius: const Radius.circular(8),
        clockwise: false,
      )
      ..lineTo(384.9, 42.68)
      ..arcToPoint(
        const Offset(398.07, 32.11),
        radius: const Radius.circular(16.45),
        clockwise: true,
      )
      ..arcToPoint(
        const Offset(414.93, 42.26),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..lineTo(437.77, 101.63)
      ..arcToPoint(
        const Offset(442.37, 106.23),
        radius: const Radius.circular(8),
        clockwise: false,
      )
      ..lineTo(501.74, 129.07)
      ..arcToPoint(
        const Offset(501.74, 158.93),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..lineTo(442.37, 181.77)
      ..arcToPoint(
        const Offset(437.77, 186.37),
        radius: const Radius.circular(8),
        clockwise: false,
      )
      ..lineTo(414.93, 245.74)
      ..arcToPoint(
        const Offset(400, 256),
        radius: const Radius.circular(16),
        clockwise: true,
      )
      ..close();
  }
}

class SparkleIconWidget extends StatelessWidget {
  const SparkleIconWidget({super.key, required this.size, required this.color});

  final double size;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        size: Size.square(size),
        painter: _SparkleIconPainter(color: color),
      ),
    );
  }
}

class _SparkleIconPainter extends CustomPainter {
  const _SparkleIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    SparkleIcon.paint(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(_SparkleIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
