import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:studyapp/common/word.dart';

/// A function that is called when a word is long-pressed.
///
/// The function can be asynchronous to allow waiting for user
/// interaction (e.g., closing a dialog).
typedef AsyncWordActionCallback = Future<void> Function(int wordId);

/// A function that returns a string to be displayed in a popup for a given word ID.
///
/// The lookup can be asynchronous (e.g., from a database or network).
/// If the function's Future resolves to null or an empty string,
/// no popup will be shown for that word.
typedef AsyncPopupWordProvider = Future<String?> Function(int wordId);

/// A callback to find a verse number at a specific Y offset
typedef VerseAtOffsetCallback = int? Function(double y);

class _LineMetrics {
  final double top;
  final double bottom;

  // The verse to show if this line is visible
  final int labelVerse;

  _LineMetrics(this.top, this.bottom, this.labelVerse);
}

/// A way for the outside world (such as scroll controllers) to obtain the
/// internal layout metrics of [HebrewGreekText].
class HebrewGreekTextController {
  final Map<int, Rect> _verseRects = {};
  VerseAtOffsetCallback? _verseAtOffsetCallback;

  /// Updates the controller with the latest verse rectangles.
  ///
  /// This is intended to be called by the RenderHebrewGreekText object.
  void _updateVerseRects(Map<int, Rect> rects) {
    _verseRects.clear();
    _verseRects.addAll(rects);
  }

  /// Registers the callback from the RenderObject
  void _registerVerseFinder(VerseAtOffsetCallback callback) {
    _verseAtOffsetCallback = callback;
  }

  /// Retrieves the [Rect] for a given verse number.
  ///
  /// The [Rect] contains the position and size of the verse number
  /// relative to the top-left corner of the HebrewGreekText widget.
  /// Returns null if the verse number is not found.
  Rect? getVerseRect(int verseNumber) {
    return _verseRects[verseNumber];
  }

  int? getVerseForOffset(double y) {
    if (_verseAtOffsetCallback != null) {
      return _verseAtOffsetCallback!(y);
    }
    return 1;
  }
}

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
    this.controller,
    this.textDirection = TextDirection.ltr,
    this.textStyle,
    this.verseNumberStyle,
    this.popupWordProvider,
    this.popupBackgroundColor,
    this.popupTextStyle,
    this.onPopupShown,
    this.onWordLongPress,
    this.flashColor,
  });

  /// The words that will rendered in the text layout
  final List<HebrewGreekWord> words;

  /// A controller to programmatically interact with the text layout,
  /// for example, to scroll to a specific verse.
  final HebrewGreekTextController? controller;

  /// RTL for Hebrew and LTR for Greek
  final TextDirection textDirection;

  /// The style of the rendered text
  final TextStyle? textStyle;

  /// The style of the rendered verse numbers
  final TextStyle? verseNumberStyle;

  /// An async function that provides the text for the popup when a word is tapped.
  final AsyncPopupWordProvider? popupWordProvider;

  /// The background color of the popup. Defaults to a dark grey.
  final Color? popupBackgroundColor;

  /// The text style for the text inside the popup. Defaults to white text.
  final TextStyle? popupTextStyle;

  /// A callback that is invoked when a popup is about to be shown.
  /// It provides the global [Rect] of the popup, allowing for actions
  /// like scrolling to ensure visibility.
  final ValueChanged<Rect>? onPopupShown;

  /// A callback that is invoked when a word is long-pressed.
  final AsyncWordActionCallback? onWordLongPress;

  /// The color of the flash effect.
  ///
  /// Defaults to the same color as [verseNumberStyle].
  final Color? flashColor;

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
    final effectivePopupTextStyle = defaultTextStyle.style.merge(
      popupTextStyle,
    );

    return RenderHebrewGreekText(
      words: words,
      controller: controller,
      textDirection: textDirection,
      style: effectiveTextStyle!,
      verseNumberStyle: effectiveVerseNumberStyle,
      popupWordProvider: popupWordProvider,
      popupBackgroundColor: popupBackgroundColor ?? Color(0xFF000000),
      popupTextStyle: effectivePopupTextStyle,
      onPopupShown: onPopupShown,
      onWordLongPress: onWordLongPress,
      flashColor:
          flashColor ??
          effectiveVerseNumberStyle?.color?.withValues(alpha: 0.4) ??
          const Color(0xFFFFFFFF),
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
    final effectivePopupTextStyle = const TextStyle(
      fontSize: 20,
      color: Color(0xFFFFFFFF),
    ).merge(popupTextStyle);

    renderObject
      ..words = words
      ..controller = controller
      ..textDirection = textDirection
      ..textStyle = effectiveTextStyle!
      ..verseNumberStyle = effectiveVerseNumberStyle
      ..popupWordProvider = popupWordProvider
      ..popupBackgroundColor = popupBackgroundColor ?? Color(0xFF000000)
      ..popupTextStyle = effectivePopupTextStyle
      ..onPopupShown = onPopupShown
      ..onWordLongPress = onWordLongPress
      ..flashColor =
          flashColor ??
          effectiveVerseNumberStyle?.color?.withValues(alpha: 0.4) ??
          const Color(0xFFFFFFFF);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<List<HebrewGreekWord>>('words', words));
    properties.add(
      DiagnosticsProperty<HebrewGreekTextController>('controller', controller),
    );
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(DiagnosticsProperty<TextStyle>('textStyle', textStyle));
    properties.add(
      DiagnosticsProperty<TextStyle>('verseNumberStyle', verseNumberStyle),
    );
    properties.add(
      ObjectFlagProperty<AsyncPopupWordProvider>.has(
        'popupWordProvider',
        popupWordProvider,
      ),
    );
    properties.add(ColorProperty('popupBackgroundColor', popupBackgroundColor));
    properties.add(
      DiagnosticsProperty<TextStyle>('popupTextStyle', popupTextStyle),
    );
    properties.add(
      ObjectFlagProperty<ValueChanged<Rect>>.has('onPopupShown', onPopupShown),
    );
    properties.add(
      ObjectFlagProperty<AsyncWordActionCallback>.has(
        'onWordLongPress',
        onWordLongPress,
      ),
    );
    properties.add(ColorProperty('flashColor', flashColor));
  }
}

class RenderHebrewGreekText extends RenderBox {
  static const maqaph = '־';

  RenderHebrewGreekText({
    required List<HebrewGreekWord> words,
    HebrewGreekTextController? controller,
    required TextDirection textDirection,
    required TextStyle style,
    required TextStyle? verseNumberStyle,
    AsyncPopupWordProvider? popupWordProvider,
    required Color popupBackgroundColor,
    required TextStyle popupTextStyle,
    ValueChanged<Rect>? onPopupShown,
    AsyncWordActionCallback? onWordLongPress,
    required Color flashColor,
  }) : _words = words,
       _controller = controller,
       _textDirection = textDirection,
       _textStyle = style,
       _verseNumberStyle = verseNumberStyle,
       _popupWordProvider = popupWordProvider,
       _popupBackgroundColor = popupBackgroundColor,
       _popupTextStyle = popupTextStyle,
       _onPopupShown = onPopupShown,
       _onWordLongPress = onWordLongPress,
       _flashColor = flashColor {
    _updatePainters();
    _tapRecognizer = TapGestureRecognizer()..onTapUp = _handleTapUp;
    _longPressRecognizer = LongPressGestureRecognizer()
      ..onLongPressStart = _handleLongPressStart;
    _controller?._registerVerseFinder(_findVerseAtOffset);
  }

  int? _tappedWordId;
  String? _popupText;
  TextPainter? _popupPainter;
  Timer? _popupDismissTimer;
  late final TapGestureRecognizer _tapRecognizer;
  late final LongPressGestureRecognizer _longPressRecognizer;
  int? _flashedWordId;
  Timer? _flashTimer;
  final List<_LineMetrics> _lineMetrics = [];

  List<HebrewGreekWord> _words;
  List<HebrewGreekWord> get words => _words;
  set words(List<HebrewGreekWord> value) {
    if (_words == value) return;
    _words = value;
    _needsPaintersUpdate = true;
    markNeedsLayout();
  }

  HebrewGreekTextController? _controller;
  HebrewGreekTextController? get controller => _controller;
  set controller(HebrewGreekTextController? value) {
    if (_controller == value) return;
    _controller = value;
    _controller?._registerVerseFinder(_findVerseAtOffset);
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

  AsyncPopupWordProvider? _popupWordProvider;
  AsyncPopupWordProvider? get popupWordProvider => _popupWordProvider;
  set popupWordProvider(AsyncPopupWordProvider? value) {
    if (_popupWordProvider == value) return;
    _popupWordProvider = value;
    if (value == null && _tappedWordId != null) {
      _dismissPopup();
    }
  }

  Color _popupBackgroundColor;
  Color get popupBackgroundColor => _popupBackgroundColor;
  set popupBackgroundColor(Color value) {
    if (_popupBackgroundColor == value) return;
    _popupBackgroundColor = value;
    if (_tappedWordId != null) {
      markNeedsPaint();
    }
  }

  TextStyle _popupTextStyle;
  TextStyle get popupTextStyle => _popupTextStyle;
  set popupTextStyle(TextStyle value) {
    if (_popupTextStyle == value) return;
    _popupTextStyle = value;
    if (_tappedWordId != null) {
      _preparePopupPainter();
      markNeedsPaint();
    }
  }

  void _preparePopupPainter() {
    if (_popupText == null || _popupText!.isEmpty) {
      _popupPainter = null;
      return;
    }
    _popupPainter = TextPainter(
      text: TextSpan(text: _popupText!, style: _popupTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  ValueChanged<Rect>? _onPopupShown;
  ValueChanged<Rect>? get onPopupShown => _onPopupShown;
  set onPopupShown(ValueChanged<Rect>? value) {
    if (_onPopupShown == value) return;
    _onPopupShown = value;
  }

  AsyncWordActionCallback? _onWordLongPress;
  AsyncWordActionCallback? get onWordLongPress => _onWordLongPress;
  set onWordLongPress(AsyncWordActionCallback? value) {
    if (_onWordLongPress == value) return;
    _onWordLongPress = value;
  }

  Color _flashColor;
  Color get flashColor => _flashColor;
  set flashColor(Color value) {
    if (_flashColor == value) return;
    _flashColor = value;
    if (_flashedWordId != null) {
      markNeedsPaint();
    }
  }

  /// Clears all popup state and requests a repaint to make it disappear.
  void _dismissPopup() {
    _popupDismissTimer?.cancel();
    _popupDismissTimer = null;

    if (_tappedWordId == null) return;
    _tappedWordId = null;
    _popupText = null;
    _popupPainter = null;
    markNeedsPaint();
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

  int? _findVerseAtOffset(double y) {
    if (_lineMetrics.isEmpty) return null;

    // Binary search to find the line containing 'y'
    int min = 0;
    int max = _lineMetrics.length - 1;
    _LineMetrics? match;
    int? closestPrevIndex;

    while (min <= max) {
      final mid = min + ((max - min) >> 1);
      final line = _lineMetrics[mid];

      if (y < line.top) {
        // Look before
        max = mid - 1;
      } else if (y > line.bottom) {
        // Look after
        min = mid + 1;
        closestPrevIndex = mid;
      } else {
        // Direct hit!
        match = line;
        break;
      }
    }

    if (match != null) {
      return match.labelVerse;
    }

    // Fallback: If we scrolled past everything (y > last line)
    // closestPrevIndex will point to the last line.
    if (closestPrevIndex != null) {
      return _lineMetrics[closestPrevIndex].labelVerse;
    }

    // Fallback: Top of screen (y < first line)
    return _lineMetrics.first.labelVerse;
  }

  Size _performLayout(BoxConstraints constraints) {
    if (_needsPaintersUpdate) {
      _updatePainters();
    }
    _wordRects.clear();
    _verseNumberRects.clear();
    _lineMetrics.clear();

    double mainAxisOffset = 0.0;
    double crossAxisOffset = 0.0;
    double currentLineMaxHeight = 0.0;
    double maxLineWidth = 0.0;

    final double availableWidth = constraints.maxWidth;
    final double spaceWidth = _spacePainter.width;
    final isLtr = _textDirection == TextDirection.ltr;

    // Temporary storage for calculating verse priority on the current line
    List<int> currentLineWordIds = [];

    // Helper to finalize a line
    void finalizeLine(double top, double bottom, List<int> wordIds) {
      if (wordIds.isEmpty) return;

      int? bestStartVerse;
      int? lowestVerseOnLine;

      for (final wordId in wordIds) {
        final verse = (wordId ~/ 100) % 1000;
        final wordNum = wordId % 100;

        if (lowestVerseOnLine == null || verse < lowestVerseOnLine!) {
          lowestVerseOnLine = verse;
        }
        if (wordNum == 1) {
          if (bestStartVerse == null || verse < bestStartVerse!) {
            bestStartVerse = verse;
          }
        }
      }

      // Priority: Start Verse > Lowest Visible
      final label = bestStartVerse ?? lowestVerseOnLine ?? 1;
      _lineMetrics.add(_LineMetrics(top, bottom, label));
      wordIds.clear();
    }

    mainAxisOffset = isLtr ? 0.0 : availableWidth;

    for (int i = 0; i < _wordPainters.length; i++) {
      final wordPainter = _wordPainters[i];
      final wordSize = wordPainter.size;
      final currentWord = _words[i];

      // Check if this word has an associated verse number
      final versePainter = _verseNumberPainters[currentWord.id];
      final verseNumberSize = versePainter?.size ?? Size.zero;
      final verseNumberUnitWidth = versePainter != null
          ? verseNumberSize.width + spaceWidth
          : 0.0;

      // "No orphan" rule: Check if the verse number AND its word fit together
      final totalUnitWidth = verseNumberUnitWidth + wordSize.width;
      final bool fitsOnLine = isLtr
          ? mainAxisOffset + totalUnitWidth <= availableWidth
          : mainAxisOffset - totalUnitWidth >= 0;

      // Line wrap logic
      if (!fitsOnLine) {
        // --- End of previous line ---
        finalizeLine(
          crossAxisOffset,
          crossAxisOffset + currentLineMaxHeight,
          currentLineWordIds,
        );

        crossAxisOffset += currentLineMaxHeight;
        currentLineMaxHeight = 0.0;
        mainAxisOffset = isLtr ? 0.0 : availableWidth;
      }

      // Track word for the current line
      currentLineWordIds.add(currentWord.id);

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

    // Finalize the last line
    finalizeLine(
      crossAxisOffset,
      crossAxisOffset + currentLineMaxHeight,
      currentLineWordIds,
    );

    final Map<int, Rect> verseRectsMap = {};
    for (final entry in _verseNumberRects.entries) {
      final wordId = entry.key;
      final rect = entry.value;
      final verseNumber = (_getVerseNumber(
        _words.firstWhere((w) => w.id == wordId),
      ))!;
      verseRectsMap[verseNumber] = rect;
    }
    controller?._updateVerseRects(verseRectsMap);

    final double finalHeight = crossAxisOffset + currentLineMaxHeight;
    final double finalWidth = constraints.hasBoundedWidth
        ? availableWidth
        : maxLineWidth;

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
    totalWidth += _wordPainters.fold(0.0, (sum, p) => sum + p.width);
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

    // Check verse numbers first
    for (final entry in _verseNumberRects.entries.toList().reversed) {
      final int wordId = entry.key;
      final Rect rect = entry.value;
      if (rect.contains(position)) {
        final verseNumber = (_getVerseNumber(
          _words.firstWhere((w) => w.id == wordId),
        ))!;
        result.add(VerseNumberHitTestEntry(this, verseNumber));
        return true;
      }
    }

    // Then check words
    for (final entry in _wordRects.entries.toList().reversed) {
      final int wordId = entry.key;
      final Rect rect = entry.value;
      if (rect.contains(position)) {
        result.add(HebrewGreekWordHitTestEntry(this, wordId));
        return true;
      }
    }

    // If no specific word or verse number was hit, the tap was on the background.
    // Let the default behavior (from super.hitTest) add a generic BoxHitTestEntry.
    return super.hitTest(result, position: position);
  }

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    if (event is PointerDownEvent) {
      _tapRecognizer.addPointer(event);
      _longPressRecognizer.addPointer(event);
    }
  }

  /// Performs a hit test at a given offset and returns the specific entry.
  HitTestEntry? _getHitTestEntryForOffset(Offset offset) {
    final result = BoxHitTestResult();
    // Use the existing hitTest method to populate the result
    if (hitTest(result, position: offset)) {
      // Return the most specific entry (which is added last)
      return result.path.last.target == this ? result.path.last : null;
    }
    return null;
  }

  /// This method is called by the [TapGestureRecognizer] only when a tap is confirmed.
  void _handleTapUp(TapUpDetails details) {
    // Use our helper to find out what was under the user's finger.
    final entry = _getHitTestEntryForOffset(details.localPosition);

    if (entry is VerseNumberHitTestEntry) {
      debugPrint('Tapped on verse number: ${entry.verseNumber}');
      _dismissPopup();
      return;
    }

    if (_popupWordProvider == null) return;

    if (entry is HebrewGreekWordHitTestEntry) {
      _popupDismissTimer?.cancel();

      final tappedId = entry.wordId;

      _tappedWordId = tappedId;
      _popupText = null;
      _popupPainter = null;
      markNeedsPaint(); // Hide any old popup immediately

      _popupWordProvider!(tappedId).then((resultText) {
        if (_tappedWordId == tappedId) {
          if (resultText != null && resultText.isNotEmpty) {
            _popupText = resultText;
            _preparePopupPainter();

            // Notify parent about the popup rect for potential scrolling.
            final tappedWordRect = _wordRects[tappedId];
            if (tappedWordRect != null) {
              final localPopupRect = _getPopupRect(tappedWordRect);
              final globalTopLeft = localToGlobal(localPopupRect.topLeft);
              final globalPopupRect = globalTopLeft & localPopupRect.size;
              onPopupShown?.call(globalPopupRect);
            }

            markNeedsPaint();
            _popupDismissTimer = Timer(
              const Duration(seconds: 3),
              _dismissPopup,
            );
          } else {
            _dismissPopup();
          }
        }
      });
    } else {
      // The tap was on the background of the widget,
      // not on a specific word or verse number.
      _dismissPopup();
    }
  }

  Rect _getPopupRect(Rect tappedWordRect) {
    final popupSize = _popupPainter!.size;

    // Center the popup horizontally above the tapped word.
    double popupContentX = tappedWordRect.center.dx - (popupSize.width / 2);
    // Position it vertically above the tapped word.
    const double verticalMargin = 6.0;
    double popupContentY =
        tappedWordRect.top - popupSize.height - verticalMargin;

    // Adjust to stay within the render box's horizontal bounds.
    if (popupContentX < 0.0) {
      popupContentX = 0.0;
    }
    if (popupContentX + popupSize.width > size.width) {
      popupContentX = size.width - popupSize.width;
    }

    return Rect.fromLTWH(
      popupContentX - kPopupHorizontalPadding,
      popupContentY - kPopupVerticalPadding,
      popupSize.width + kPopupHorizontalPadding * 2,
      popupSize.height + kPopupVerticalPadding * 2,
    );
  }

  /// This method is called by the [LongPressGestureRecognizer].
  Future<void> _handleLongPressStart(LongPressStartDetails details) async {
    // Find out what was under the user's finger.
    final entry = _getHitTestEntryForOffset(details.localPosition);
    if (onWordLongPress == null) return;
    if (entry is HebrewGreekWordHitTestEntry) {
      _dismissPopup();
      // Await the parent's action (e.g., for the dialog to be closed)
      await onWordLongPress!(entry.wordId);

      // After the action is complete, trigger the flash internally.
      _flashedWordId = entry.wordId;
      markNeedsPaint();

      // Clear the flash after a short duration.
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 1500), () {
        _flashedWordId = null;
        markNeedsPaint();
      });
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_words.isEmpty) return;

    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    // 0. Paint the flash effect if a word is being flashed
    if (_flashedWordId != null) {
      final rect = _wordRects[_flashedWordId];
      if (rect != null) {
        final flashPaint = Paint()..color = _flashColor;
        final rrect = RRect.fromRectAndRadius(
          rect.inflate(2.0),
          const Radius.circular(4.0),
        );
        canvas.drawRRect(rrect, flashPaint);
      }
    }

    // 1. Paint all the words
    for (int i = 0; i < _wordPainters.length; i++) {
      final wordId = _words[i].id;
      final rect = _wordRects[wordId];
      final painter = _wordPainters[i];
      if (rect != null) {
        painter.paint(canvas, rect.topLeft);
      }
    }

    // 2. Paint all the verse numbers
    for (final entry in _verseNumberPainters.entries) {
      final wordId = entry.key;
      final painter = entry.value;
      final rect = _verseNumberRects[wordId];
      if (rect != null) {
        painter.paint(canvas, rect.topLeft);
      }
    }

    // 3. Paint the popup if a word is tapped AND its painter is ready
    if (_tappedWordId != null && _popupPainter != null) {
      final tappedWordRect = _wordRects[_tappedWordId];
      if (tappedWordRect != null) {
        _paintPopup(canvas, tappedWordRect);
      }
    }

    canvas.restore();
  }

  static const double kPopupVerticalPadding = 4.0;
  static const double kPopupHorizontalPadding = 8.0;

  void _paintPopup(Canvas canvas, Rect tappedWordRect) {
    // Draw the background.
    const double kPopupCornerRadius = 8.0;
    final bgRect = _getPopupRect(tappedWordRect);
    final bgPaint = Paint()..color = _popupBackgroundColor;
    final rrect = RRect.fromRectAndRadius(
      bgRect,
      const Radius.circular(kPopupCornerRadius),
    );
    canvas.drawRRect(rrect, bgPaint);

    // Paint the text.
    final textOffset = Offset(
      bgRect.left + kPopupHorizontalPadding,
      bgRect.top + kPopupVerticalPadding,
    );
    _popupPainter!.paint(canvas, textOffset);
  }

  @override
  void detach() {
    _tapRecognizer.dispose();
    _longPressRecognizer.dispose();
    _popupDismissTimer?.cancel();
    _flashTimer?.cancel();
    super.detach();
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
