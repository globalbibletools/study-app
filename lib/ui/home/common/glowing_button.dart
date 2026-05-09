import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

class GlowingButton extends StatefulWidget {
  const GlowingButton({
    super.key,
    required this.primaryColor,
    required this.child,
    required this.duration,
    required this.borderRadius,
    this.glowInset = 8,
    this.strokeWidth = 4,
  });

  final Color primaryColor;
  final Widget child;
  final int duration;
  final double borderRadius;
  final double glowInset;
  final double strokeWidth;

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    )..repeat();
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
      child: Padding(
        padding: EdgeInsets.all(widget.glowInset),
        child: widget.child,
      ),
      builder: (context, child) {
        return CustomPaint(
          painter: _FlowingBorderGlowPainter(
            progress: _controller.value,
            primaryColor: widget.primaryColor,
            borderRadius: widget.borderRadius,
            glowInset: widget.glowInset,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        );
      },
    );
  }
}

class _FlowingBorderGlowPainter extends CustomPainter {
  const _FlowingBorderGlowPainter({
    required this.progress,
    required this.primaryColor,
    required this.borderRadius,
    required this.glowInset,
    required this.strokeWidth,
  });

  final double progress;
  final Color primaryColor;
  final double borderRadius;
  final double glowInset;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(glowInset, glowInset) &
        Size(size.width - glowInset * 2, size.height - glowInset * 2);
    final radius = Radius.circular(borderRadius);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final path = Path()..addRRect(rrect);
    final metric = path.computeMetrics().first;
    final pathLength = metric.length;
    final headDistance = progress * pathLength;
    final trailLength = math.max(pathLength * 0.22, 80.0);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = primaryColor.withValues(alpha: 0.14);

    canvas.drawRRect(rrect, basePaint);

    _drawFlowingLine(
      canvas: canvas,
      metric: metric,
      headDistance: headDistance,
      pathLength: pathLength,
      trailLength: trailLength,
      strokeWidth: strokeWidth + strokeWidth,
      blurSigma: 9,
      alphaScale: 0.7,
    );
    _drawFlowingLine(
      canvas: canvas,
      metric: metric,
      headDistance: headDistance,
      pathLength: pathLength,
      trailLength: trailLength,
      strokeWidth: strokeWidth,
      blurSigma: 0,
      alphaScale: 1,
    );
  }

  void _drawFlowingLine({
    required Canvas canvas,
    required PathMetric metric,
    required double headDistance,
    required double pathLength,
    required double trailLength,
    required double strokeWidth,
    required double blurSigma,
    required double alphaScale,
  }) {
    const segments = 20;

    for (var i = 0; i < segments; i++) {
      final segmentStart =
          headDistance - trailLength + (trailLength / segments) * i;
      final segmentEnd =
          headDistance - trailLength + (trailLength / segments) * (i + 1);
      final intensity = (i + 1) / segments;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(
          primaryColor,
          Colors.white,
          intensity * 0.35,
        )!.withValues(alpha: intensity * alphaScale);

      if (blurSigma > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      }

      _drawWrappedSegment(
        canvas,
        metric,
        segmentStart,
        segmentEnd,
        pathLength,
        paint,
      );
    }
  }

  void _drawWrappedSegment(
    Canvas canvas,
    PathMetric metric,
    double start,
    double end,
    double pathLength,
    Paint paint,
  ) {
    var normalizedStart = start % pathLength;
    var normalizedEnd = end % pathLength;

    if (normalizedStart < 0) normalizedStart += pathLength;
    if (normalizedEnd < 0) normalizedEnd += pathLength;

    if (normalizedStart <= normalizedEnd) {
      canvas.drawPath(
        metric.extractPath(normalizedStart, normalizedEnd),
        paint,
      );
      return;
    }

    canvas.drawPath(metric.extractPath(normalizedStart, pathLength), paint);
    canvas.drawPath(metric.extractPath(0, normalizedEnd), paint);
  }

  @override
  bool shouldRepaint(covariant _FlowingBorderGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.glowInset != glowInset ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
