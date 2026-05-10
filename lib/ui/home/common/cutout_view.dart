import 'package:flutter/material.dart';

class SpotlightObject {
  final GlobalKey key;
  final double inflate;
  final double radius;

  SpotlightObject({
    required this.key,
    required this.inflate,
    required this.radius,
  });
}

class CutoutRect {
  final Rect rect;
  final double inflate;
  final double radius;

  CutoutRect({required this.rect, required this.inflate, required this.radius});
}

class CutoutView extends StatefulWidget {
  final _panelStackKey = GlobalKey();

  final Widget content;
  final List<SpotlightObject> objects;
  final bool enabled;
  final int intensity;

  CutoutView({
    super.key,
    required this.content,
    required this.enabled,
    this.intensity = 200,
    this.objects = const [],
  });

  @override
  State<CutoutView> createState() => CutoutViewState();
}

class CutoutViewState extends State<CutoutView> {
  List<CutoutRect> cutouts = [];

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
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
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _SpotlightPainter(
            cutouts: cutouts,
            intensity: widget.intensity,
          ),
        ),
      ),
    );
  }

  void _updateSpotlightRect() {
    if (!mounted) {
      return;
    }

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

    for (SpotlightObject obj in widget.objects) {
      final context = obj.key.currentContext;
      if (context == null) {
        continue;
      }

      final box = context.findRenderObject();

      if (box is! RenderBox || !box.hasSize) {
        continue;
      }

      final topLeft = box.localToGlobal(Offset.zero, ancestor: panelBox);
      nextCutouts.add(
        CutoutRect(
          rect: topLeft & box.size,
          inflate: obj.inflate,
          radius: obj.radius,
        ),
      );
    }

    if (_sameCutouts(nextCutouts)) {
      return;
    }

    setState(() {
      cutouts = nextCutouts;
    });
  }

  void _clearSpotlights() {
    if (cutouts.isEmpty) {
      return;
    }

    setState(() {
      cutouts = [];
    });
  }

  bool _sameCutouts(List<CutoutRect> nextSpotlights) {
    if (cutouts.length != nextSpotlights.length) {
      return false;
    }

    for (int i = 0; i < cutouts.length; i++) {
      if (cutouts[i] != nextSpotlights[i]) {
        return false;
      }
    }

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
    Path buttonCutout = Path();

    for (int i = 0; i < cutouts.length; i++) {
      buttonCutout.addRRect(
        RRect.fromRectAndRadius(
          cutouts[i].rect.inflate(cutouts[i].inflate),
          Radius.circular(cutouts[i].radius),
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
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.cutouts != cutouts;
  }
}
