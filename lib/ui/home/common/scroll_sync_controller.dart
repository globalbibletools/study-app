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

/// Which edge of a verse span an [Anchor] refers to.
enum AnchorEnd { start, end }

/// A named place in a reading layout.
///
/// An anchor is either the top or bottom edge of a verse's span, or the very
/// top/bottom of the scrollable content (represented by a null [ref]).
@immutable
class Anchor {
  const Anchor(this.ref, this.end);

  /// The very top of the scrollable content.
  const Anchor.top() : ref = null, end = AnchorEnd.start;

  /// The very bottom of the scrollable content.
  const Anchor.bottom() : ref = null, end = AnchorEnd.end;

  /// The verse this anchor belongs to, or null for a scrollable extreme.
  final Reference? ref;

  /// Which edge of [ref]'s span this anchor refers to.
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

/// A position expressed as a fraction between two named places.
///
/// [t] is clamped to the inclusive range 0..1.
@immutable
class SyncPosition {
  SyncPosition(this.from, this.to, double t) : t = t.clamp(0.0, 1.0);

  final Anchor from;
  final Anchor to;

  /// How far the position is between [from] and [to].
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

  // The state to broadcast.
  SyncPosition? _position;
  Reference? _displayReference;

  SyncPosition? get position => _position;

  /// The first fully visible verse reported by the leader, if known.
  int? get displayVerse => _displayReference?.verse;

  /// Full reference of the first fully visible verse reported by the leader.
  Reference? get displayReference => _displayReference;

  /// Called by the active panel to report position.
  void updatePosition(
    Object source,
    SyncPosition position, {
    int? displayVerse,
    Reference? displayReference,
  }) {
    // Only accept updates from the panel the user is actually touching.
    if (_activeSource != null && _activeSource != source) return;

    final resolvedDisplay =
        displayReference ??
        (displayVerse == null
            ? null
            : _referenceForVerse(position, displayVerse));

    if (_position == position && _displayReference == resolvedDisplay) {
      return;
    }

    _position = position;
    _displayReference = resolvedDisplay;

    // Notify the other panel.
    notifyListeners();
  }

  /// Best-effort full reference for a bare display verse reported without one.
  static Reference? _referenceForVerse(SyncPosition position, int verse) {
    final fromRef = position.from.ref;
    final toRef = position.to.ref;

    if (toRef != null && verse >= toRef.verse) return toRef;
    if (fromRef != null && verse <= fromRef.verse) return fromRef;
    return fromRef ?? toRef;
  }

  bool isSourceActive(Object source) => _activeSource == source;

  VerseHighlight? _pendingVerseJump;
  VerseHighlight? get pendingVerseJump => _pendingVerseJump;

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
