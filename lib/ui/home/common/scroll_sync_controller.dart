import 'dart:async';

import 'package:flutter/foundation.dart';

class VerseHighlight {
  final int bookId;
  final int chapter;
  final int verse;
  final bool isAuto;

  VerseHighlight({
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.isAuto = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerseHighlight &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          chapter == other.chapter &&
          verse == other.verse &&
          isAuto == isAuto;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse, isAuto);
}

class ScrollSyncController extends ChangeNotifier {
  // Track which panel is currently being touched/scrolled by the user
  // so we don't create an infinite feedback loop.
  Object? _activeSource;
  final _verseJumpController = StreamController<VerseHighlight>.broadcast();
  Stream<VerseHighlight> get onVerseJump => _verseJumpController.stream;

  void setActiveSource(Object source) {
    _activeSource = source;
  }

  void clearActiveSource() {
    _activeSource = null;
  }

  // The state to broadcast
  int? _bookId;
  int? _chapter;
  int? _verse;
  double _progress = 0.0;

  int? get bookId => _bookId;
  int? get chapter => _chapter;
  int? get verse => _verse;
  double get progress => _progress;

  /// Called by the active panel to report position
  void updatePosition(
    Object source,
    int bookId,
    int chapter,
    double progress, {
    int? verse,
  }) {
    // Only accept updates from the panel the user is actually touching
    if (_activeSource != null && _activeSource != source) return;

    _bookId = bookId;
    _chapter = chapter;
    _verse = verse;
    _progress = progress;

    // Notify the other panel
    notifyListeners();
  }

  /// Called by a passive panel (one being automatically scrolled) to
  /// report the verse it landed on, providing better metadata
  /// than the active driver might possess.
  void reportAutoDetectedVerse(int verse) {
    // If the verse hasn't changed, don't notify to save performance
    if (_verse == verse) return;

    _verse = verse;
    notifyListeners();
  }

  bool isSourceActive(Object source) => _activeSource == source;

  void jumpToVerse(int bookId, int chapter, int verse, {bool isAuto = false}) {
    _verseJumpController.add(
      VerseHighlight(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        isAuto: isAuto,
      ),
    );
  }

  final highlightNotifier = ValueNotifier<VerseHighlight?>(null);

  void setHighlight(int bookId, int chapter, int? verse) {
    if (verse == null) {
      if (highlightNotifier.value != null) {
        highlightNotifier.value = null;
      }
      return;
    }

    final newState = VerseHighlight(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
    );
    if (highlightNotifier.value != newState) {
      highlightNotifier.value = newState;
    }
  }

  @override
  void dispose() {
    _verseJumpController.close();
    highlightNotifier.dispose();
    super.dispose();
  }
}
