import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gbt/ui/common/sparkle_icon.dart';

class WordPopup {
  const WordPopup({
    required this.text,
    this.isAiGenerated = false,
    this.textDirection = TextDirection.ltr,
  });

  final String text;
  final bool isAiGenerated;
  final TextDirection textDirection;

  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  /// Dismisses any currently visible floating word popup.
  static void dismissActive() {
    _activeTimer?.cancel();
    _activeTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }

  /// Displays a floating word gloss popup anchored at [anchorPosition].
  static OverlayEntry? show({
    required BuildContext context,
    required Offset anchorPosition,
    required WordPopup popup,
    VoidCallback? onDismiss,
  }) {
    dismissActive();

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return null;

    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    bool allowDismissOnTapOutside = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      allowDismissOnTapOutside = true;
    });

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (!allowDismissOnTapOutside) return;
                  dismissActive();
                  onDismiss?.call();
                },
              ),
            ),
            CustomSingleChildLayout(
              delegate: _WordPopupPositionDelegate(
                anchorPosition: anchorPosition,
                topPadding: topPadding,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (popup.isAiGenerated) ...[
                        CustomPaint(
                          size: const Size(13, 13),
                          painter: _SparkleCustomPainter(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        popup.text,
                        textDirection: popup.textDirection,
                        style: TextStyle(
                          fontFamily: 'sbl',
                          fontSize: 14.0,
                          color: theme.colorScheme.onInverseSurface,
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
    );

    _activeEntry = entry;
    overlayState.insert(entry);

    _activeTimer = Timer(const Duration(seconds: 3), () {
      dismissActive();
      onDismiss?.call();
    });

    return entry;
  }
}

class _WordPopupPositionDelegate extends SingleChildLayoutDelegate {
  final Offset anchorPosition;
  final double topPadding;

  const _WordPopupPositionDelegate({
    required this.anchorPosition,
    required this.topPadding,
  });

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = anchorPosition.dx - childSize.width / 2;
    if (x < 16.0) x = 16.0;
    if (x + childSize.width > size.width - 16.0) {
      x = size.width - 16.0 - childSize.width;
    }

    double y = anchorPosition.dy - childSize.height - 8.0;
    if (y < topPadding + 16.0) {
      // Place below anchor if not enough room above
      y = anchorPosition.dy + 24.0;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(covariant _WordPopupPositionDelegate oldDelegate) {
    return oldDelegate.anchorPosition != anchorPosition ||
        oldDelegate.topPadding != topPadding;
  }
}

class _SparkleCustomPainter extends CustomPainter {
  final Color color;

  const _SparkleCustomPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    SparkleIcon.paint(canvas, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(covariant _SparkleCustomPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
