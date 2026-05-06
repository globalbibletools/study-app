import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_controller.value),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(50);

    final origins = [
      Offset(size.width * 0.3, size.height * 0.15),
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.15),
    ];

    final particleCount = 200;

    for (int i = 0; i < particleCount; i++) {
      final baseColor = Colors.primaries[i % Colors.primaries.length];

      // smoother fade
      final opacity = (1.0 - math.pow(progress, 1.5)).clamp(0.0, 1.0);
      final paint = Paint()..color = baseColor.withOpacity(opacity);

      // pick a burst origin
      final origin = origins[i % origins.length];

      // fully random angle (not evenly spaced)
      final angle = random.nextDouble() * 2 * math.pi;

      // variable speed (more natural)
      final speed = 100 + random.nextDouble() * 220;

      // slight stagger (particles don't all move equally)
      final localProgress = (progress - (i % 10) * 0.01).clamp(0.0, 1.0);

      final dx = math.cos(angle) * speed * localProgress;
      final dy = math.sin(angle) * speed * localProgress;

      // stronger gravity curve
      final gravity = 320 * localProgress * localProgress;

      // horizontal drift (wind effect)
      final drift = math.sin(progress * 3 + i) * 20;

      final position = origin.translate(dx + drift, dy + gravity);

      // larger, more paper-like shapes
      final width = 6 + random.nextDouble() * 8;
      final height = width * (0.4 + random.nextDouble() * 0.6);

      canvas.save();
      canvas.translate(position.dx, position.dy);

      // varied rotation speed
      final rotation = angle + progress * (2 + random.nextDouble() * 4);
      canvas.rotate(rotation);

      // draw mostly rectangles (real confetti look)
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: width,
        height: height,
      );
      canvas.drawRect(rect, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return true;
  }
}
