import 'package:flutter/foundation.dart';

class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  final List<VoidCallback> _listeners = [];

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// Specific exception to throw when user cancels
class DownloadCanceledException implements Exception {
  final String message;
  DownloadCanceledException([this.message = "Download canceled by user"]);
  @override
  String toString() => message;
}
