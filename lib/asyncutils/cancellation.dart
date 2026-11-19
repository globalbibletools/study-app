typedef Guard = Future<T> Function<T>(Future<T> future);

class CancelledError implements Exception {
  const CancelledError(this.source, [this.reason]);

  final CancellationToken source;
  final Object? reason;

  @override
  String toString() =>
      reason == null ? 'CancelledError' : 'CancelledError: $reason';
}

class CancellationToken {
  var _cancelled = false;
  Object? _reason;

  bool get isCancelled => _cancelled;

  void cancel([Object? reason]) {
    if (_cancelled) return;
    _cancelled = true;
    _reason = reason;
  }

  Future<T> guard<T>(Future<T> future) async {
    if (_cancelled) throw CancelledError(this, _reason);

    final T result;
    try {
      result = await future;
    } catch (e) {
      if (_cancelled) throw CancelledError(this, _reason);
      rethrow;
    }

    if (_cancelled) throw CancelledError(this, _reason);
    return result;
  }
}

class CancellationScope {
  CancellationToken? _current;

  Future<void> run(Future<void> Function(Guard guard) action) async {
    final token = CancellationToken();
    _current?.cancel();
    _current = token;

    try {
      await action(token.guard);
    } on CancelledError catch (error) {
      if (!identical(error.source, token)) rethrow;
    } finally {
      if (identical(_current, token)) _current = null;
    }
  }

  void cancelAll([Object? reason]) {
    _current?.cancel(reason);
  }
}
