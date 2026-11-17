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
          isAuto == other.isAuto;

  @override
  int get hashCode => Object.hash(bookId, chapter, verse, isAuto);
}

enum AnchorEnd { start, end }

@immutable
class Anchor {
  const Anchor(this.ref, this.end);

  const Anchor.top() : ref = null, end = AnchorEnd.start;
  const Anchor.bottom() : ref = null, end = AnchorEnd.end;

  final Reference? ref;
  final AnchorEnd end;

  bool get isTop => ref == null && end == AnchorEnd.start;
  bool get isBottom => ref == null && end == AnchorEnd.end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Anchor &&
          runtimeType == other.runtimeType &&
          ref == other.ref &&
          end == other.end;

  @override
  int get hashCode => Object.hash(ref, end);

  @override
  String toString() {
    if (ref == null) return isTop ? 'Anchor.top' : 'Anchor.bottom';
    return 'Anchor(${ref!.bookId}:${ref!.chapter}:${ref!.verse}, $end)';
  }
}

@immutable
class SyncPosition {
  SyncPosition(this.from, this.to, double t) : t = t.clamp(0.0, 1.0);

  final Anchor from;
  final Anchor to;
  final double t;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncPosition &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          t == other.t;

  @override
  int get hashCode => Object.hash(from, to, t);

  @override
  String toString() => 'SyncPosition($from -> $to @ ${t.toStringAsFixed(4)})';
}

/// Reports whose anchors and display reference match the last accepted
/// report and whose [SyncPosition.t] differs by less than this are treated as
/// duplicates and do not notify listeners.
const double _syncTolerance = 0.005;

class ScrollSyncController extends ChangeNotifier {
  VerseHighlight? _pendingVerseJump;
  final _verseJumpController = StreamController<VerseHighlight>.broadcast();
  Stream<VerseHighlight> get onVerseJump => _verseJumpController.stream;
  VerseHighlight? get pendingVerseJump => _pendingVerseJump;

  ValueNotifier<Reference?>? _audioReferenceNotifier;

  Object? _activeSource;
  bool isSourceActive(Object source) => _activeSource == source;
  void setActiveSource(Object source) {
    _activeSource = source;
  }

  void clearActiveSource() {
    _activeSource = null;
  }

  SyncPosition? _position;
  SyncPosition? get position => _position;

  Reference? _displayReference;
  Reference? get displayReference => _displayReference;

  void updatePosition(
    Object source,
    SyncPosition position, {
    required Reference? displayReference,
  }) {
    if (_activeSource != null && _activeSource != source) return;

    if (_position != null &&
        _position!.from == position.from &&
        _position!.to == position.to &&
        _displayReference == displayReference &&
        (position.t - _position!.t).abs() < _syncTolerance) {
      return;
    }

    _position = position;
    _displayReference = displayReference;

    notifyListeners();
  }

  void jumpToVerse(int bookId, int chapter, int verse, {bool isAuto = false}) {
    final target = VerseHighlight(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      isAuto: isAuto,
    );
    _pendingVerseJump = target;
    _verseJumpController.add(target);
  }

  void clearPendingJump() {
    _pendingVerseJump = null;
  }

  void listenToAudioReference(ValueNotifier<Reference?> reference) {
    if (identical(_audioReferenceNotifier, reference)) return;

    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    _audioReferenceNotifier = reference;
    _audioReferenceNotifier?.addListener(_onAudioReferenceChanged);
  }

  void _onAudioReferenceChanged() {
    // Don't override the user scrolling.
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
