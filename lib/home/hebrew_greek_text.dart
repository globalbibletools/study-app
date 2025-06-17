import 'dart:math' as math;
import 'package:database_builder/database_builder.dart';
import 'package:flutter/material.dart'; // For TextStyle and DefaultTextStyle
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that renders Hebrew and Greek text with custom layout and styling.
///
/// This widget takes a list of [HebrewGreekWord] objects and renders them according
/// to the specified [textDirection] and [style]. It handles proper text layout and
/// styling for both Hebrew and Greek text.
///
/// Example:
///
/// HebrewGreekText(
///   words: [HebrewGreekWord(...)],
///   textDirection: TextDirection.rtl,
///   style: TextStyle(fontSize: 18),
/// )
///
class HebrewGreekText extends LeafRenderObjectWidget {
  const HebrewGreekText({
    super.key,
    required this.words,
    this.textDirection = TextDirection.ltr,
    this.style,
  });

  /// The words that will rendered in the text layout
  final List<HebrewGreekWord> words;

  /// RTL for Hebrew and LTR for Greek
  final TextDirection textDirection;

  /// The style of the rendered text
  final TextStyle? style;

  @override
  RenderHebrewGreekText createRenderObject(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    var effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }

    return RenderHebrewGreekText(
      words: words,
      textDirection: textDirection,
      style: effectiveTextStyle!,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHebrewGreekText renderObject,
  ) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    var effectiveTextStyle = style;
    if (style == null || style!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(style);
    }

    renderObject
      ..words = words
      ..textDirection = textDirection
      ..style = effectiveTextStyle!;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<List<HebrewGreekWord>>('words', words));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

class RenderHebrewGreekText extends RenderBox {
  RenderHebrewGreekText({
    required List<HebrewGreekWord> words,
    required TextDirection textDirection,
    required TextStyle style,
  }) : _words = words,
       _textDirection = textDirection,
       _style = style {
    _updatePainters();
  }

  List<HebrewGreekWord> _words;
  List<HebrewGreekWord> get words => _words;
  set words(List<HebrewGreekWord> value) {
    if (_words == value) return;
    _words = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  TextStyle _style;
  TextStyle get style => _style;
  set style(TextStyle value) {
    if (_style == value) return;
    _style = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  // Cached layout data
  bool _needsPaintersUpdate = true;
  final List<TextPainter> _wordPainters = [];
  late TextPainter _spacePainter;
  final Map<int, Rect> _wordRects = {};

  void _updatePainters() {
    // Create a painter for the space
    _spacePainter = TextPainter(
      text: TextSpan(text: ' ', style: _style),
      textDirection: _textDirection,
    )..layout();

    // Create a painter for each word
    _wordPainters.clear();
    for (final word in _words) {
      final painter = TextPainter(
        text: TextSpan(text: word.text, style: _style),
        textDirection: _textDirection,
      )..layout();
      _wordPainters.add(painter);
    }
    _needsPaintersUpdate = false;
  }

  // A private layout method to be shared by performLayout and computeDryLayout
  Size _performLayout(BoxConstraints constraints) {
    if (_needsPaintersUpdate) {
      _updatePainters();
    }
    _wordRects.clear();

    double mainAxisOffset = 0.0;
    double crossAxisOffset = 0.0;
    double currentLineMaxHeight = 0.0;
    double maxLineWidth = 0.0;

    final double availableWidth = constraints.maxWidth;
    final double spaceWidth = _spacePainter.width;
    final isLtr = _textDirection == TextDirection.ltr;

    // Set starting position based on text direction
    mainAxisOffset = isLtr ? 0.0 : availableWidth;

    for (int i = 0; i < _wordPainters.length; i++) {
      final wordPainter = _wordPainters[i];
      final wordSize = wordPainter.size;

      final bool fitsOnLine =
          isLtr
              ? mainAxisOffset + wordSize.width <= availableWidth
              : mainAxisOffset - wordSize.width >= 0;

      // Line wrap logic
      if (!fitsOnLine) {
        // Move to the next line
        crossAxisOffset += currentLineMaxHeight;
        currentLineMaxHeight = 0.0;
        mainAxisOffset = isLtr ? 0.0 : availableWidth;
      }

      // Track the max height on the current line
      currentLineMaxHeight = math.max(currentLineMaxHeight, wordSize.height);

      // Position and store Rect
      final Rect wordRect;
      if (isLtr) {
        wordRect = Rect.fromLTWH(
          mainAxisOffset,
          crossAxisOffset,
          wordSize.width,
          wordSize.height,
        );
        mainAxisOffset += wordSize.width + spaceWidth;
      } else {
        // RTL
        mainAxisOffset -= wordSize.width;
        wordRect = Rect.fromLTWH(
          mainAxisOffset,
          crossAxisOffset,
          wordSize.width,
          wordSize.height,
        );
        mainAxisOffset -= spaceWidth;
      }
      _wordRects[_words[i].id] = wordRect;

      // Track the maximum width used.
      if (isLtr) {
        maxLineWidth = math.max(maxLineWidth, mainAxisOffset - spaceWidth);
      } else {
        maxLineWidth = math.max(
          maxLineWidth,
          availableWidth - (mainAxisOffset + spaceWidth),
        );
      }
    }

    final double finalHeight = crossAxisOffset + currentLineMaxHeight;
    final double finalWidth =
        constraints.hasBoundedWidth ? availableWidth : maxLineWidth;

    return Size(finalWidth, finalHeight);
  }

  @override
  void performLayout() {
    size = _performLayout(constraints);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    // Dry layout doesn't need to store the rects, but the calculation is the same.
    // A more optimized version could skip storing rects, but this is clear and correct.
    return _performLayout(constraints);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_needsPaintersUpdate) _updatePainters();
    return _wordPainters.fold(0.0, (max, p) => math.max(max, p.width));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_needsPaintersUpdate) _updatePainters();
    final double totalWordWidth = _wordPainters.fold(
      0.0,
      (sum, p) => sum + p.width,
    );
    final double totalSpaceWidth =
        (_wordPainters.length - 1) * _spacePainter.width;
    return totalWordWidth + totalSpaceWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeDryLayout(BoxConstraints.tightFor(width: width)).height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return computeDryLayout(BoxConstraints.tightFor(width: width)).height;
  }

  // This is required for hit testing to work correctly on RenderObjects
  // that are not parents of other RenderObjects.
  @override
  bool hitTestSelf(Offset position) {
    // Check if the given position falls within the bounding box of any word.
    for (final rect in _wordRects.values) {
      if (rect.contains(position)) {
        return true;
      }
    }
    return false;
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    // Can be used to handle tap, hover, etc.
    // For example, if you wanted to implement a word-level tap handler.
    if (event is PointerDownEvent && entry is HebrewGreekWordHitTestEntry) {
      // A word was tapped! You can use entry.wordId here.
      debugPrint('Tapped on word with ID: ${entry.wordId}');
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // First, ensure the hit is within the painted bounds of the render box.
    if (!size.contains(position)) {
      return false;
    }

    // Check if the hit position is inside the bounding box of any word.
    // We iterate in reverse because later words are painted on top in case of
    // any strange overlap, so they should be hit-tested first.
    for (final entry in _wordRects.entries.toList().reversed) {
      final int wordId = entry.key;
      final Rect rect = entry.value;
      if (rect.contains(position)) {
        // A word was hit. Add a standard entry for the RenderBox itself
        // and our custom entry with the specific word ID.
        result.add(BoxHitTestEntry(this, position));
        result.add(HebrewGreekWordHitTestEntry(this, wordId));
        return true; // Absorb the hit, stop testing objects behind this one.
      }
    }

    // The hit was within our bounds but not on any specific word (e.g., in a space).
    // In this case, we return false because we only want a "positive" hit test
    // on the words themselves. If you wanted the whole box to be tappable, you
    // could add a `BoxHitTestEntry` and return true here.
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_words.isEmpty) return;

    final canvas = context.canvas;
    // The offset is the position of this RenderBox within its parent.
    // We must add this offset to all our local coordinates.
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (int i = 0; i < _wordPainters.length; i++) {
      final wordId = _words[i].id;
      final rect = _wordRects[wordId];
      final painter = _wordPainters[i];
      if (rect != null) {
        painter.paint(canvas, rect.topLeft);
      }
    }

    canvas.restore();
  }
}

// A custom HitTestEntry to carry the specific word ID that was hit.
class HebrewGreekWordHitTestEntry extends HitTestEntry {
  HebrewGreekWordHitTestEntry(this.renderObject, this.wordId)
    : super(renderObject);

  final RenderHebrewGreekText renderObject;
  final int wordId;

  @override
  String toString() =>
      '${renderObject.runtimeType} hit test with word ID: $wordId';
}
