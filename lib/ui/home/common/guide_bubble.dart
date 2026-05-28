import 'package:flutter/material.dart';

class GuideBubble extends StatefulWidget {
  const GuideBubble({
    super.key,
    required this.targetGlobalRect,
    required this.panelAreaKey,
    required this.onDismiss,
    this.title,
    required this.text,
    required this.dismissText,
  });

  final Rect targetGlobalRect;
  final GlobalKey panelAreaKey;
  final VoidCallback onDismiss;
  final String? title;
  final String text;
  final String dismissText;

  @override
  State<GuideBubble> createState() => _GuideBubbleState();
}

class _GuideBubbleState extends State<GuideBubble> {
  Rect? _localTargetRect;
  bool _resolveScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleResolveLocalTargetRect();
  }

  @override
  void didUpdateWidget(covariant GuideBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetGlobalRect != widget.targetGlobalRect ||
        oldWidget.panelAreaKey != widget.panelAreaKey) {
      _localTargetRect = null;
      _scheduleResolveLocalTargetRect();
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleResolveLocalTargetRect();

    final localTarget = _localTargetRect;
    if (localTarget == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const horizontalPadding = 16.0;
          const bubbleHeightEstimate = 150.0;
          final belowTop = localTarget.bottom + 18;
          final aboveTop = localTarget.top - bubbleHeightEstimate - 18;
          final maxTop = constraints.maxHeight > bubbleHeightEstimate + 12
              ? constraints.maxHeight - bubbleHeightEstimate
              : 12.0;
          final top = belowTop + bubbleHeightEstimate <= constraints.maxHeight
              ? belowTop
              : aboveTop.clamp(12.0, maxTop).toDouble();

          return Stack(
            children: [
              Positioned(
                top: top,
                left: horizontalPadding,
                right: horizontalPadding,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null)
                          Text(
                            widget.title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (widget.title != null) const SizedBox(height: 8),

                        Text(widget.text, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                            onPressed: widget.onDismiss,
                            child: Text(widget.dismissText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scheduleResolveLocalTargetRect() {
    if (_resolveScheduled) return;
    _resolveScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveScheduled = false;

      final panelBox =
          widget.panelAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (panelBox == null || !panelBox.hasSize) {
        _scheduleResolveLocalTargetRect();
        return;
      }

      final nextRect =
          panelBox.globalToLocal(widget.targetGlobalRect.topLeft) &
          widget.targetGlobalRect.size;
      if (_sameRect(_localTargetRect, nextRect)) return;
      setState(() => _localTargetRect = nextRect);
    });
  }

  bool _sameRect(Rect? a, Rect b) {
    if (a == null) return false;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
  }
}
