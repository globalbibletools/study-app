import 'package:flutter/foundation.dart';
import 'package:gbt/common/reference.dart';

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

  bool _lastUpdateAnimated = false;

  /// Whether the most recent accepted position update was requested as an
  /// animated seek. Panels use this to animate instead of jumping.
  bool get lastUpdateAnimated => _lastUpdateAnimated;

  bool _lastUpdateIsSeek = false;

  /// Whether the most recent accepted position update came from [seekTo].
  /// Scroll-follow reports never set this; panels use it to apply the
  /// "breathing room" offset only when converging on an explicit seek.
  bool get lastUpdateIsSeek => _lastUpdateIsSeek;

  /// Reports a panel's scroll position. The active-source gate is load-bearing
  /// for seek semantics: while a panel owns the scroll, other reports (and
  /// [seekTo]) are ignored so the reader never fights the user's finger.
  void updatePosition(
    Object source,
    SyncPosition position, {
    required Reference? displayReference,
    bool animated = false,
  }) {
    _applyPosition(
      source,
      position,
      displayReference: displayReference,
      animated: animated,
      isSeek: false,
    );
  }

  /// Seeks the reader to [ref]. Authoritative position write: panels converge
  /// to this via their alignment path. Gated like audio: ignored while a panel
  /// is the active source (callers doing explicit navigation must clear first).
  void seekTo(Reference ref, {bool animated = false}) {
    if (_activeSource != null) return;
    final anchor = Anchor(ref, AnchorEnd.start);
    _applyPosition(
      'manager', // pseudo-source, already used for seeded positions
      SyncPosition(anchor, anchor, 0.0),
      displayReference: ref,
      animated: animated,
      isSeek: true,
    );
  }

  void _applyPosition(
    Object source,
    SyncPosition position, {
    required Reference? displayReference,
    required bool animated,
    required bool isSeek,
  }) {
    if (_activeSource != null && _activeSource != source) return;

    _lastUpdateAnimated = animated;
    _lastUpdateIsSeek = isSeek;

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

    seekTo(reference, animated: true);
  }

  @override
  void dispose() {
    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    super.dispose();
  }
}
