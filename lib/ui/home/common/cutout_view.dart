import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SpotlightObject {
  final GlobalKey? key;
  final Rect? rect;
  final bool isGlobalRect;
  final double inflate;
  final double radius;

  const SpotlightObject.fromKey({
    required GlobalKey this.key,
    this.inflate = 0,
    this.radius = 0,
  }) : rect = null,
       isGlobalRect = false;

  const SpotlightObject.fromRect({
    required Rect this.rect,
    this.inflate = 0,
    this.radius = 0,
  }) : key = null,
       isGlobalRect = false;

  const SpotlightObject.fromGlobalRect({
    required Rect this.rect,
    this.inflate = 0,
    this.radius = 0,
  }) : key = null,
       isGlobalRect = true;
}

class CutoutRect {
  final Rect rect;
  final double inflate;
  final double radius;
  const CutoutRect({
    required this.rect,
    required this.inflate,
    required this.radius,
  });

  @override
  bool operator ==(Object other) {
    return other is CutoutRect &&
        other.rect == rect &&
        other.inflate == inflate &&
        other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(rect, inflate, radius);
}

enum TouchState { allowAll, allowUnderSpotlight, disableAll }

class CutoutView extends StatefulWidget {
  final _panelStackKey = GlobalKey();
  final Widget content;
  final List<SpotlightObject> objects;
  final bool enabled;
  final int intensity;
  final TouchState touchState;

  CutoutView({
    super.key,
    required this.content,
    required this.enabled,
    this.intensity = 200,
    this.objects = const [],
    this.touchState = TouchState.allowUnderSpotlight,
  });

  @override
  State<CutoutView> createState() => CutoutViewState();
}

class CutoutViewState extends State<CutoutView> {
  List<CutoutRect> cutouts = [];

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    if (!enabled || widget.objects.isEmpty) {
      return widget.content;
    }

    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSpotlightRect();
      });
    }

    return Stack(
      key: widget._panelStackKey,
      children: [widget.content, if (enabled) _drawSpotlights()],
    );
  }

  Widget _drawSpotlights() {
    final Widget child;

    if (widget.touchState == TouchState.allowAll) {
      child = IgnorePointer(
        child: CustomPaint(
          painter: _SpotlightPainter(
            cutouts: cutouts,
            intensity: widget.intensity,
          ),
        ),
      );
    } else {
      child = _CutoutHitBlocker(
        cutouts: widget.touchState == TouchState.allowUnderSpotlight
            ? cutouts
            : [],
        child: CustomPaint(
          painter: _SpotlightPainter(
            cutouts: cutouts,
            intensity: widget.intensity,
          ),
        ),
      );
    }

    return Positioned.fill(child: child);
  }

  void _updateSpotlightRect() {
    if (!mounted) return;

    final panelContext = widget._panelStackKey.currentContext;
    if (panelContext == null) {
      _clearSpotlights();
      return;
    }

    final panelBox = panelContext.findRenderObject();
    if (panelBox == null || panelBox is! RenderBox || !panelBox.hasSize) {
      _clearSpotlights();
      return;
    }

    final nextCutouts = <CutoutRect>[];

    for (final obj in widget.objects) {
      final Rect? resolvedRect;

      if (obj.rect != null) {
        resolvedRect = obj.isGlobalRect
            ? panelBox.globalToLocal(obj.rect!.topLeft) & obj.rect!.size
            : obj.rect;
      } else {
        // Resolve position from the GlobalKey
        final ctx = obj.key!.currentContext;
        if (ctx == null) continue;

        final box = ctx.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;

        resolvedRect =
            box.localToGlobal(Offset.zero, ancestor: panelBox) & box.size;
      }

      nextCutouts.add(
        CutoutRect(
          rect: resolvedRect!,
          inflate: obj.inflate,
          radius: obj.radius,
        ),
      );
    }

    if (_sameCutouts(nextCutouts)) return;
    setState(() => cutouts = nextCutouts);
  }

  void _clearSpotlights() {
    if (cutouts.isEmpty) return;
    setState(() => cutouts = []);
  }

  bool _sameCutouts(List<CutoutRect> nextSpotlights) {
    if (cutouts.length != nextSpotlights.length) return false;
    for (int i = 0; i < cutouts.length; i++) {
      if (cutouts[i] != nextSpotlights[i]) return false;
    }
    return true;
  }
}

class _CutoutHitBlocker extends SingleChildRenderObjectWidget {
  final List<CutoutRect> cutouts;

  const _CutoutHitBlocker({required this.cutouts, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCutoutHitBlocker(cutouts);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderCutoutHitBlocker renderObject,
  ) {
    renderObject.cutouts = cutouts;
  }
}

class _RenderCutoutHitBlocker extends RenderProxyBox {
  List<CutoutRect> _cutouts;

  _RenderCutoutHitBlocker(this._cutouts);

  set cutouts(List<CutoutRect> value) {
    if (_cutouts == value) return;
    _cutouts = value;
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    for (final cutout in _cutouts) {
      final rect = cutout.rect.inflate(cutout.inflate);

      // Allow touches to pass through spotlight areas.
      if (rect.contains(position)) {
        return false;
      }
    }

    // Block touches outside spotlight areas.
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.cutouts, required this.intensity});

  final int intensity;
  final List<CutoutRect> cutouts;

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreen = Path()..addRect(Offset.zero & size);
    final buttonCutout = Path();

    for (final c in cutouts) {
      buttonCutout.addRRect(
        RRect.fromRectAndRadius(
          c.rect.inflate(c.inflate),
          Radius.circular(c.radius),
        ),
      );
    }

    final mask = Path.combine(
      PathOperation.difference,
      fullScreen,
      buttonCutout,
    );
    canvas.drawPath(mask, Paint()..color = Colors.black.withAlpha(intensity));
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.cutouts != cutouts;
}
