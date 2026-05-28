import 'package:flutter/material.dart';

class GlobalRectReporter extends StatefulWidget {
  const GlobalRectReporter({
    super.key,
    required this.child,
    required this.onRectChanged,
  });

  final Widget child;
  final ValueChanged<Rect?>? onRectChanged;

  @override
  State<GlobalRectReporter> createState() => _GlobalRectReporterState();
}

class _GlobalRectReporterState extends State<GlobalRectReporter> {
  final _key = GlobalKey();
  Rect? _lastRect;

  @override
  void initState() {
    super.initState();
    _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant GlobalRectReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReport();
  }

  @override
  void dispose() {
    widget.onRectChanged?.call(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return KeyedSubtree(key: _key, child: widget.child);
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) {
        _reportIfChanged(null);
        return;
      }

      final rect = box.localToGlobal(Offset.zero) & box.size;
      _reportIfChanged(rect);
    });
  }

  void _reportIfChanged(Rect? rect) {
    if (_sameRect(_lastRect, rect)) return;
    _lastRect = rect;
    widget.onRectChanged?.call(rect);
  }

  bool _sameRect(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
  }
}
