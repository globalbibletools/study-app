import 'package:flutter/foundation.dart';

class ScrollSyncController extends ChangeNotifier {
  // Track which panel is currently being touched/scrolled by the user
  // so we don't create an infinite feedback loop.
  Object? _activeSource;

  void setActiveSource(Object source) {
    _activeSource = source;
  }

  void clearActiveSource() {
    _activeSource = null;
  }

  // The state to broadcast
  int? _bookId;
  int? _chapter;
  double _progress = 0.0;

  int? get bookId => _bookId;
  int? get chapter => _chapter;
  double get progress => _progress;

  /// Called by the "Master" panel to report position
  void updatePosition(Object source, int bookId, int chapter, double progress) {
    // Only accept updates from the panel the user is actually touching
    if (_activeSource != null && _activeSource != source) return;

    _bookId = bookId;
    _chapter = chapter;
    _progress = progress;

    // Notify the "Slave" panel
    notifyListeners();
  }

  bool isSourceActive(Object source) => _activeSource == source;
}
