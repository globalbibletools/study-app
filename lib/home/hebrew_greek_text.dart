import 'dart:math' as math;
import 'package:database_builder/database_builder.dart';
import 'package:flutter/material.dart'; // For TextStyle and DefaultTextStyle
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that renders Hebrew and Greek text with custom layout and styling.
///
/// This widget takes a list of [HebrewGreekWord] objects and renders them according
/// to the specified [textDirection] and [textStyle]. It handles proper text layout and
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
    this.textStyle,
    this.verseNumberStyle,
  });

  /// The words that will rendered in the text layout
  final List<HebrewGreekWord> words;

  /// RTL for Hebrew and LTR for Greek
  final TextDirection textDirection;

  /// The style of the rendered text
  final TextStyle? textStyle;

  /// The style of the rendered verse numbers
  final TextStyle? verseNumberStyle;

  @override
  RenderHebrewGreekText createRenderObject(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    var effectiveTextStyle = textStyle;
    if (textStyle == null || textStyle!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(textStyle);
    }
    var effectiveVerseNumberStyle = verseNumberStyle;
    if (verseNumberStyle == null || verseNumberStyle!.inherit) {
      effectiveVerseNumberStyle = effectiveTextStyle!.merge(verseNumberStyle);
    }

    return RenderHebrewGreekText(
      words: words,
      textDirection: textDirection,
      style: effectiveTextStyle!,
      verseNumberStyle: effectiveVerseNumberStyle,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHebrewGreekText renderObject,
  ) {
    final defaultTextStyle = DefaultTextStyle.of(context);
    var effectiveTextStyle = textStyle;
    if (textStyle == null || textStyle!.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(textStyle);
    }
    var effectiveVerseNumberStyle = verseNumberStyle;
    if (verseNumberStyle == null || verseNumberStyle!.inherit) {
      effectiveVerseNumberStyle = effectiveTextStyle!.merge(verseNumberStyle);
    }

    renderObject
      ..words = words
      ..textDirection = textDirection
      ..textStyle = effectiveTextStyle!
      ..verseNumberStyle = effectiveVerseNumberStyle;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<List<HebrewGreekWord>>('words', words));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(DiagnosticsProperty<TextStyle>('textStyle', textStyle));
    properties.add(
      DiagnosticsProperty<TextStyle>('verseNumberStyle', verseNumberStyle),
    );
  }
}

class RenderHebrewGreekText extends RenderBox {
  static const maqaph = '־';

  RenderHebrewGreekText({
    required List<HebrewGreekWord> words,
    required TextDirection textDirection,
    required TextStyle style,
    required TextStyle? verseNumberStyle,
  }) : _words = words,
       _textDirection = textDirection,
       _textStyle = style,
       _verseNumberStyle = verseNumberStyle {
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

  TextStyle _textStyle;
  TextStyle get textStyle => _textStyle;
  set textStyle(TextStyle value) {
    if (_textStyle == value) return;
    _textStyle = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  TextStyle? _verseNumberStyle;
  TextStyle? get verseNumberStyle => _verseNumberStyle;
  set verseNumberStyle(TextStyle? value) {
    if (_verseNumberStyle == value) return;
    _verseNumberStyle = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  // Cached layout data
  bool _needsPaintersUpdate = true;
  final List<TextPainter> _wordPainters = [];
  late TextPainter _spacePainter;
  final Map<int, Rect> _wordRects = {};
  final Map<int, TextPainter> _verseNumberPainters = {};
  final Map<int, Rect> _verseNumberRects = {};

  void _updatePainters() {
    _spacePainter = TextPainter(
      text: TextSpan(text: ' ', style: _textStyle),
      textDirection: _textDirection,
    )..layout();

    _wordPainters.clear();
    _verseNumberPainters.clear();
    for (final word in _words) {
      // Create painter for the word
      final wordPainter = TextPainter(
        text: TextSpan(text: word.text, style: _textStyle),
        textDirection: _textDirection,
      )..layout();
      _wordPainters.add(wordPainter);

      // Create painter for the verse number if it's the first word
      final verseNumber = _getVerseNumber(word);
      if (verseNumber != null) {
        final versePainter = TextPainter(
          text: TextSpan(text: '$verseNumber', style: _verseNumberStyle),
          textDirection: _textDirection,
        )..layout();
        // Use the word's ID as the key to associate them
        _verseNumberPainters[word.id] = versePainter;
      }
    }
    _needsPaintersUpdate = false;
  }

  /// Extracts the verse number if the word is the first in a verse.
  int? _getVerseNumber(HebrewGreekWord word) {
    final wordNumber = word.id % 100;
    if (wordNumber != 1) return null;
    return (word.id ~/ 100) % 1000;
  }

  Size _performLayout(BoxConstraints constraints) {
    if (_needsPaintersUpdate) {
      _updatePainters();
    }
    _wordRects.clear();
    _verseNumberRects.clear();

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
      final currentWord = _words[i];

      // Check if this word has an associated verse number
      final versePainter = _verseNumberPainters[currentWord.id];
      final verseNumberSize = versePainter?.size ?? Size.zero;
      final verseNumberUnitWidth =
          versePainter != null ? verseNumberSize.width + spaceWidth : 0.0;

      // "NO ORPHAN" RULE: Check if the verse number AND its word fit together
      final totalUnitWidth = verseNumberUnitWidth + wordSize.width;
      final bool fitsOnLine =
          isLtr
              ? mainAxisOffset + totalUnitWidth <= availableWidth
              : mainAxisOffset - totalUnitWidth >= 0;

      // Line wrap logic
      if (!fitsOnLine) {
        // Move to the next line
        crossAxisOffset += currentLineMaxHeight;
        currentLineMaxHeight = 0.0;
        mainAxisOffset = isLtr ? 0.0 : availableWidth;
      }

      // Track the max height on the current line
      currentLineMaxHeight = math.max(
        currentLineMaxHeight,
        math.max(wordSize.height, verseNumberSize.height),
      );

      final bool endsWithMaqaph = _words[i].text.endsWith(maqaph);
      final double effectiveSpaceWidth = endsWithMaqaph ? 0.0 : spaceWidth;

      // Position and store Rect
      if (isLtr) {
        // 1. Position verse number if it exists
        if (versePainter != null) {
          final verseRect = Rect.fromLTWH(
            mainAxisOffset,
            crossAxisOffset,
            verseNumberSize.width,
            verseNumberSize.height,
          );
          _verseNumberRects[currentWord.id] = verseRect;
          mainAxisOffset += verseNumberUnitWidth;
        }
        // 2. Position the word
        final wordRect = Rect.fromLTWH(
          mainAxisOffset,
          crossAxisOffset,
          wordSize.width,
          wordSize.height,
        );
        _wordRects[currentWord.id] = wordRect;
        mainAxisOffset += wordSize.width + effectiveSpaceWidth;
      } else {
        // RTL
        // 1. Position verse number if it exists (at the rightmost available spot)
        if (versePainter != null) {
          // Move cursor left by the width of the number to find its top-left
          mainAxisOffset -= verseNumberSize.width;
          final verseRect = Rect.fromLTWH(
            mainAxisOffset,
            crossAxisOffset,
            verseNumberSize.width,
            verseNumberSize.height,
          );
          _verseNumberRects[currentWord.id] = verseRect;
          mainAxisOffset -= spaceWidth;
        }
        // 2. Position the word to the left of the verse number (or at the start)
        mainAxisOffset -= wordSize.width;
        final wordRect = Rect.fromLTWH(
          mainAxisOffset,
          crossAxisOffset,
          wordSize.width,
          wordSize.height,
        );
        _wordRects[currentWord.id] = wordRect;
        // 3. Account for the space before the next element
        mainAxisOffset -= effectiveSpaceWidth;
      }

      // Track the maximum width used.
      if (isLtr) {
        maxLineWidth = math.max(
          maxLineWidth,
          mainAxisOffset - effectiveSpaceWidth,
        );
      } else {
        maxLineWidth = math.max(
          maxLineWidth,
          availableWidth - (mainAxisOffset + effectiveSpaceWidth),
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
    return _performLayout(constraints);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_needsPaintersUpdate) _updatePainters();
    if (_words.isEmpty) return 0.0;

    double maxWidth = 0.0;
    for (int i = 0; i < _words.length; i++) {
      final word = _words[i];
      final wordPainter = _wordPainters[i];
      final versePainter = _verseNumberPainters[word.id];
      double unitWidth = wordPainter.width;
      if (versePainter != null) {
        unitWidth += versePainter.width + _spacePainter.width;
      }
      maxWidth = math.max(maxWidth, unitWidth);
    }
    return maxWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_needsPaintersUpdate) _updatePainters();
    if (_words.isEmpty) return 0.0;

    double totalWidth = 0.0;

    // Sum of all word widths
    totalWidth += _wordPainters.fold(0.0, (sum, p) => sum + p.width);

    // Sum of all verse number widths and the space that follows each one
    totalWidth += _verseNumberPainters.values.fold(
      0.0,
      (sum, p) => sum + p.width + _spacePainter.width,
    );

    // Sum of inter-word spaces, skipping words that end with a maqaph.
    for (int i = 0; i < _words.length - 1; i++) {
      if (!_words[i].text.endsWith(maqaph)) {
        totalWidth += _spacePainter.width;
      }
    }
    return totalWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return computeDryLayout(BoxConstraints.tightFor(width: width)).height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return computeDryLayout(BoxConstraints.tightFor(width: width)).height;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) {
      return false;
    }

    // Check verse numbers FIRST
    for (final entry in _verseNumberRects.entries.toList().reversed) {
      final int wordId = entry.key;
      final Rect rect = entry.value;
      if (rect.contains(position)) {
        final verseNumber =
            (_getVerseNumber(_words.firstWhere((w) => w.id == wordId)))!;
        result.add(BoxHitTestEntry(this, position));
        result.add(VerseNumberHitTestEntry(this, verseNumber));
        return true;
      }
    }

    // Then check words
    for (final entry in _wordRects.entries.toList().reversed) {
      final int wordId = entry.key;
      final Rect rect = entry.value;
      if (rect.contains(position)) {
        result.add(BoxHitTestEntry(this, position));
        result.add(HebrewGreekWordHitTestEntry(this, wordId));
        return true;
      }
    }

    return false;
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (event is PointerDownEvent) {
      if (entry is VerseNumberHitTestEntry) {
        debugPrint('Tapped on verse number: ${entry.verseNumber}');
        // You can add a callback here, e.g., onVerseNumberTapped?.call(entry.verseNumber);
      } else if (entry is HebrewGreekWordHitTestEntry) {
        debugPrint('Tapped on word with ID: ${entry.wordId}');
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_words.isEmpty) return;

    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // 1. Paint all the words
    for (int i = 0; i < _wordPainters.length; i++) {
      final wordId = _words[i].id;
      final rect = _wordRects[wordId];
      final painter = _wordPainters[i];
      if (rect != null) {
        painter.paint(canvas, rect.topLeft);
      }
    }

    // 2. Paint all the verse numbers on top
    for (final entry in _verseNumberPainters.entries) {
      final wordId = entry.key;
      final painter = entry.value;
      final rect = _verseNumberRects[wordId];
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

// A custom HitTestEntry to carry the specific verse number that was hit.
class VerseNumberHitTestEntry extends HitTestEntry {
  VerseNumberHitTestEntry(this.renderObject, this.verseNumber)
    : super(renderObject);

  final RenderHebrewGreekText renderObject;
  final int verseNumber;

  @override
  String toString() =>
      '${renderObject.runtimeType} hit test with verse number: $verseNumber';
}
