import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/settings/user_settings.dart';

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

const double _syncTolerance = 0.005;

@immutable
class HardNavigation {
  const HardNavigation(this.reference);

  final Reference reference;
}

class NavigationViewModel extends ChangeNotifier {
  NavigationViewModel(this._settings)
    : anchor = ValueNotifier(_restoredReference(_settings)) {
    final ref = anchor.value;
    _lastSavedReference = ref;

    final top = Anchor(ref, AnchorEnd.start);
    _applyPosition(
      'manager',
      SyncPosition(top, top, 0.0),
      displayReference: ref,
      animated: false,
      isSeek: true,
    );
  }

  final UserSettings _settings;

  final StreamController<HardNavigation> _hardNavigationController =
      StreamController<HardNavigation>.broadcast(sync: true);

  Stream<HardNavigation> get hardNavigation => _hardNavigationController.stream;

  final ValueNotifier<Reference> anchor;

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

  Reference? get currentReference => _displayReference ?? _chapterOf(_position);

  Reference? _lastSavedReference;

  bool _lastUpdateAnimated = false;

  bool get lastUpdateAnimated => _lastUpdateAnimated;

  bool _lastUpdateIsSeek = false;

  bool get lastUpdateIsSeek => _lastUpdateIsSeek;

  static Reference _restoredReference(UserSettings settings) {
    return settings.currentReference;
  }

  void navigateTo(
    Reference ref, {
    bool persist = true,
    bool animated = false,
    bool hard = true,
  }) {
    clearActiveSource();
    _writeChapterAnchor(ref);
    _seek(ref, animated: animated);
    if (persist) unawaited(_persistReference(ref));
    if (hard) _hardNavigationController.add(HardNavigation(ref));
  }

  void seekTo(Reference ref, {bool animated = false}) {
    clearActiveSource();
    _persistSeek(ref, animated: animated);
  }

  void _persistSeek(Reference ref, {required bool animated}) {
    if (_seek(ref, animated: animated)) {
      unawaited(_persistReference(ref));
    }
  }

  bool _seek(Reference ref, {required bool animated}) {
    final anchor = Anchor(ref, AnchorEnd.start);
    return _applyPosition(
      'manager',
      SyncPosition(anchor, anchor, 0.0),
      displayReference: ref,
      animated: animated,
      isSeek: true,
    );
  }

  void reportPosition(
    Object panelId,
    SyncPosition position, {
    Reference? display,
  }) {
    final changed = _applyPosition(
      panelId,
      position,
      displayReference: display,
      animated: false,
      isSeek: false,
    );
    if (changed) _persistCurrentReference();
  }

  void reanchorToCurrentReference() {
    final ref = currentReference;
    if (ref != null) _writeChapterAnchor(ref);
  }

  Future<void> persistCurrentChapter() => _persistCurrentReference();

  void _writeChapterAnchor(Reference ref) {
    final current = anchor.value;
    if (current.bookId == ref.bookId && current.chapter == ref.chapter) {
      return;
    }
    anchor.value = Reference(
      bookId: ref.bookId,
      chapter: ref.chapter,
      verse: 1,
    );
  }

  bool _applyPosition(
    Object source,
    SyncPosition position, {
    required Reference? displayReference,
    required bool animated,
    required bool isSeek,
  }) {
    if (_activeSource != null && _activeSource != source) return false;

    _lastUpdateAnimated = animated;
    _lastUpdateIsSeek = isSeek;

    if (_position != null &&
        _position!.from == position.from &&
        _position!.to == position.to &&
        _displayReference == displayReference &&
        (position.t - _position!.t).abs() < _syncTolerance) {
      return false;
    }

    _position = position;
    _displayReference = displayReference;

    notifyListeners();
    return true;
  }

  Future<void> _persistCurrentReference() {
    final ref = currentReference;
    if (ref == null) return Future.value();
    return _persistReference(ref);
  }

  Future<void> _persistReference(Reference ref) async {
    final last = _lastSavedReference;
    if (last != null &&
        last.bookId == ref.bookId &&
        last.chapter == ref.chapter &&
        last.verse == ref.verse) {
      return;
    }
    _lastSavedReference = ref;
    await _settings.setCurrentReference(ref);
  }

  Reference? _chapterOf(SyncPosition? position) {
    if (position == null) return null;

    final from = position.from.ref;
    final to = position.to.ref;
    if (from == null && to == null) return null;

    if (from != null && to != null) {
      if (from.bookId == to.bookId && from.chapter == to.chapter) return from;
      return position.t < 0.5 ? from : to;
    }

    return from ?? to;
  }

  void bindAudioReference(ValueNotifier<Reference?> reference) {
    if (identical(_audioReferenceNotifier, reference)) return;

    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    _audioReferenceNotifier = reference;
    _audioReferenceNotifier?.addListener(_onAudioReferenceChanged);
  }

  void _onAudioReferenceChanged() {
    if (_activeSource != null) return;

    final reference = _audioReferenceNotifier?.value;
    if (reference == null) return;

    _persistSeek(reference, animated: true);
  }

  @override
  void dispose() {
    unawaited(_hardNavigationController.close());
    _audioReferenceNotifier?.removeListener(_onAudioReferenceChanged);
    anchor.dispose();
    super.dispose();
  }
}
