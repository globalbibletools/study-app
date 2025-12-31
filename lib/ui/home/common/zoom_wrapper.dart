import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ZoomWrapper extends StatefulWidget {
  const ZoomWrapper({
    super.key,
    required this.initialScale,
    required this.onScaleChanged,
    required this.builder,
  });

  /// The starting font scale (e.g. 1.0).
  final double initialScale;

  /// Called when the user finishes a zoom gesture and the scale is committed.
  final ValueChanged<double> onScaleChanged;

  /// Builds the child widget.
  /// [scale] is the committed scale factor to be used for font size calculation.
  final Widget Function(BuildContext context, double scale) builder;

  @override
  State<ZoomWrapper> createState() => _ZoomWrapperState();
}

class _ZoomWrapperState extends State<ZoomWrapper> {
  // The scale at the end of the last zoom gesture.
  late double _baseScale;

  // The current scale during a zoom gesture.
  late double _currentScale;

  // The scale at the beginning of the current zoom gesture.
  double _gestureStartScale = 1.0;

  // The alignment for the Transform.scale, calculated from the gesture's focal point.
  Alignment _transformAlignment = Alignment.center;

  @override
  void initState() {
    super.initState();
    _baseScale = widget.initialScale;
    _currentScale = widget.initialScale;
  }

  @override
  void didUpdateWidget(covariant ZoomWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialScale != oldWidget.initialScale &&
        widget.initialScale != _baseScale) {
      // Sync state if parent updates the scale (e.g. from settings reset)
      _baseScale = widget.initialScale;
      _currentScale = widget.initialScale;
    }
  }

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(),
            (ScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  _gestureStartScale = _baseScale;
                  _updateTransformAlignment(details.localFocalPoint);
                }
                ..onUpdate = (details) {
                  setState(() {
                    // Update current scale visually
                    _currentScale = (_gestureStartScale * details.scale).clamp(
                      0.5,
                      5.0,
                    );
                  });
                }
                ..onEnd = (details) {
                  setState(() {
                    _baseScale = _currentScale;
                  });
                  // Persist the change
                  widget.onScaleChanged(_baseScale);
                };
            },
          ),
    };
  }

  void _updateTransformAlignment(Offset localFocalPoint) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    setState(() {
      _transformAlignment = _calculateAlignment(
        renderBox.size,
        localFocalPoint,
      );
    });
  }

  Alignment _calculateAlignment(Size widgetSize, Offset focalPoint) {
    final dx = focalPoint.dx.clamp(0.0, widgetSize.width);
    final dy = focalPoint.dy.clamp(0.0, widgetSize.height);
    return Alignment(
      (dx / widgetSize.width) * 2 - 1,
      (dy / widgetSize.height) * 2 - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: _zoomGesture,
      behavior: HitTestBehavior.translucent,
      child: Transform.scale(
        // While zooming, we scale the visual layer.
        // When not zooming (_baseScale == _currentScale), scale is 1.0,
        // but the child is rebuilt with the new font size.
        scale: _baseScale > 0 ? _currentScale / _baseScale : 1.0,
        alignment: _transformAlignment,
        child: widget.builder(context, _baseScale),
      ),
    );
  }
}
