import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/ui/messaging/ephemeral_message.dart';

/// App-wide owner of ephemeral messages.
///
/// Exactly one message is visible at a time. Additional messages wait in a
/// queue ordered by severity (`error > warning > success > info`) and, within
/// one severity, by arrival order. A higher-priority arrival does not preempt
/// the visible message; it moves to the front of the pending queue and shows
/// when the visible message is dismissed.
///
/// Timers belong to the visible message only. A queued message has no running
/// timer, so its full duration starts when it becomes visible.
class MessengerViewModel extends ChangeNotifier {
  EphemeralMessage? _visible;
  final List<EphemeralMessage> _pending = [];
  Timer? _timer;
  int _nextId = 0;

  /// The message currently on screen, or `null` when nothing is showing.
  EphemeralMessage? get visibleMessage => _visible;

  /// Messages waiting to be shown, in arrival order.
  List<EphemeralMessage> get pendingMessages => List.unmodifiable(_pending);

  bool get hasPendingMessages => _pending.isNotEmpty;

  String showInfo(String text) => _show(MessageSeverity.info, text);

  String showSuccess(String text) => _show(MessageSeverity.success, text);

  String showWarning(String text) => _show(MessageSeverity.warning, text);

  String showError(String text) => _show(MessageSeverity.error, text);

  String _show(MessageSeverity severity, String text) {
    final existing = _findIdentical(severity, text);
    if (existing != null) {
      // Coalesce: never duplicate the same severity + text. If it is already
      // visible, restart its timer so the user gets the full reading time. A
      // queued duplicate keeps its place in the queue.
      if (identical(existing, _visible)) {
        _startTimer();
      }
      return existing.id;
    }

    final message = EphemeralMessage(
      id: 'message-${++_nextId}',
      severity: severity,
      text: text,
      duration: severity.duration,
    );

    if (_visible == null) {
      _visible = message;
      _startTimer();
    } else {
      _pending.add(message);
    }
    notifyListeners();
    return message.id;
  }

  EphemeralMessage? _findIdentical(MessageSeverity severity, String text) {
    bool matches(EphemeralMessage message) =>
        message.severity == severity && message.text == text;

    final visible = _visible;
    if (visible != null && matches(visible)) return visible;
    for (final message in _pending) {
      if (matches(message)) return message;
    }
    return null;
  }

  /// Dismisses the visible message, if any, and shows the next queued one.
  void dismissVisible() {
    if (_visible == null) return;

    _timer?.cancel();
    _timer = null;
    _visible = null;

    if (_pending.isNotEmpty) {
      _visible = _takeNext();
      _startTimer();
    }

    notifyListeners();
  }

  EphemeralMessage _takeNext() {
    var bestIndex = 0;
    for (var i = 1; i < _pending.length; i++) {
      // Strictly greater keeps earlier arrivals first within a severity.
      if (_pending[i].severity.priority >
          _pending[bestIndex].severity.priority) {
        bestIndex = i;
      }
    }
    return _pending.removeAt(bestIndex);
  }

  void _startTimer() {
    _timer?.cancel();
    final message = _visible;
    if (message == null) {
      _timer = null;
      return;
    }
    _timer = Timer(message.duration, dismissVisible);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending.clear();
    _visible = null;
    super.dispose();
  }
}
