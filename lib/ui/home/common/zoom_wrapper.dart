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
  // The visual scale multiplier applied via Transform.scale during a pinch
  // gesture. Resets to 1.0 after each gesture ends.
  double _visualScale = 1.0;

  // The alignment for the Transform.scale, calculated from the gesture's focal point.
  Alignment _transformAlignment = Alignment.center;

  // The absolute scale at the start of the current gesture, captured from
  // widget.initialScale so the reported value is correct even if the active
  // language changed since the widget was last built.
  double _gestureStartAbsoluteScale = 1.0;

  Map<Type, GestureRecognizerFactory<GestureRecognizer>> get _zoomGesture {
    return {
      CustomScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<CustomScaleGestureRecognizer>(
            () => CustomScaleGestureRecognizer(),
            (CustomScaleGestureRecognizer instance) {
              instance
                ..onStart = (details) {
                  _gestureStartAbsoluteScale = widget.initialScale;
                  _updateTransformAlignment(details.localFocalPoint);
                }
                ..onUpdate = (details) {
                  setState(() {
                    _visualScale = details.scale.clamp(
                      0.5 / _gestureStartAbsoluteScale,
                      5.0 / _gestureStartAbsoluteScale,
                    );
                  });
                }
                ..onEnd = (details) {
                  final newAbsoluteScale =
                      (_gestureStartAbsoluteScale * _visualScale).clamp(
                        0.5,
                        5.0,
                      );
                  // Only persist if the scale actually changed (not a
                  // single-finger scroll that produced scale ≈ 1.0).
                  if ((_visualScale - 1.0).abs() > 0.01) {
                    widget.onScaleChanged(newAbsoluteScale);
                  }
                  setState(() {
                    _visualScale = 1.0;
                  });
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
        // During a pinch gesture, _visualScale != 1.0 provides the live
        // preview.  Between gestures it is always 1.0, so no transform is
        // applied and the children render at their natural font size.
        scale: _visualScale,
        alignment: _transformAlignment,
        child: widget.builder(context, widget.initialScale),
      ),
    );
  }
}

/// Custom recognizer that listens only for scaling (pinch) gestures.
/// It overrides rejectGesture to forcefully accept the gesture only when
/// two or more pointers are down (an actual pinch). For single-finger
/// scrolls the gesture is rejected normally so the scroll view wins.
class CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  CustomScaleGestureRecognizer({super.debugOwner});

  int _pointerCount = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointerCount++;
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerCount--;
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (_pointerCount >= 2) {
      // Two-finger pinch: force-accept so zoom wins over scroll
      acceptGesture(pointer);
    } else {
      // Single-finger: let scroll gesture win normally
      super.rejectGesture(pointer);
    }
  }
}
