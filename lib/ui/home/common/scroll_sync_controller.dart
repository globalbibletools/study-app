import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/common/reference.dart';

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

  ValueNotifier<Reference?>? _audioReferenceNotifier;

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

  void listenToAudioReference(ValueNotifier<Reference?> reference) {
    if (identical(_audioReferenceNotifier, reference)) return;

    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    _audioReferenceNotifier = reference;
    _audioReferenceNotifier?.addListener(_onAudioReferenceChanged);
  }

  void _onAudioReferenceChanged() {
    // Don't override the user scrolling
    if (_activeSource != null) return;

    final reference = _audioReferenceNotifier?.value;
    if (reference == null) return;

    jumpToVerse(
      reference.bookId,
      reference.chapter,
      reference.verse,
      isAuto: true,
    );
  }

  @override
  void dispose() {
    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    _verseJumpController.close();
    super.dispose();
  }
}
