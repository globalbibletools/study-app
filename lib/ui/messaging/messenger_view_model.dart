import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gbt/ui/messaging/ephemeral_message.dart';

class MessengerViewModel extends ChangeNotifier {
  EphemeralMessage? _visible;
  final List<EphemeralMessage> _pending = [];
  Timer? _timer;
  int _nextId = 0;

  EphemeralMessage? get visibleMessage => _visible;

  List<EphemeralMessage> get pendingMessages => List.unmodifiable(_pending);

  bool get hasPendingMessages => _pending.isNotEmpty;

  String showInfo(String text) => _show(MessageSeverity.info, text);

  String showSuccess(String text) => _show(MessageSeverity.success, text);

  String showWarning(String text) => _show(MessageSeverity.warning, text);

  String showError(String text) => _show(MessageSeverity.error, text);

  String _show(MessageSeverity severity, String text) {
    final visibleId = _refreshVisibleDuplicate(severity, text);
    if (visibleId != null) return visibleId;

    final queuedDuplicate = _findQueuedDuplicate(severity, text);
    if (queuedDuplicate != null) return queuedDuplicate.id;

    final message = EphemeralMessage(
      id: 'message-${++_nextId}',
      severity: severity,
      text: text,
    );

    if (_visible == null) {
      _visible = message;
      _startTimer();
      notifyListeners();
    } else {
      _pending.add(message);
    }
    return message.id;
  }

  String? _refreshVisibleDuplicate(MessageSeverity severity, String text) {
    final visible = _visible;
    if (visible == null || !_matches(visible, severity, text)) return null;
    _startTimer();
    return visible.id;
  }

  EphemeralMessage? _findQueuedDuplicate(
    MessageSeverity severity,
    String text,
  ) {
    for (final message in _pending) {
      if (_matches(message, severity, text)) return message;
    }
    return null;
  }

  bool _matches(
    EphemeralMessage message,
    MessageSeverity severity,
    String text,
  ) {
    return message.severity == severity && message.text == text;
  }

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
    _timer = Timer(message.severity.visibilityTimeout, dismissVisible);
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
