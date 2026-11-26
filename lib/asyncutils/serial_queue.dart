import 'dart:async';

class SerialQueueClosed implements Exception {
  const SerialQueueClosed();

  @override
  String toString() => 'SerialQueueClosed';
}

class InFlightError implements Exception {
  const InFlightError(this.key);

  final Object key;

  @override
  String toString() => 'InFlightError($key)';
}

class SerialQueue {
  final List<_QueueEntry> _pending = [];
  final Map<Object, Future<Object?>> _coalesced = {};
  final Set<Object> _inFlightKeys = {};

  _QueueEntry? _current;
  Completer<void>? _idleCompleter;
  Future<void>? _closeFuture;

  bool _closed = false;
  bool get isClosed => _closed;

  Future<void> get idle {
    if (_current == null && _pending.isEmpty) return Future<void>.value();

    return (_idleCompleter ??= Completer<void>()).future;
  }

  /// Queue an [action] that must be run serially in the queue.
  Future<T> run<T>(Future<T> Function() action) {
    if (_closed) return Future<T>.error(const SerialQueueClosed());

    final task = _QueueTask<T>(action);
    _enqueue(task);
    return task.result;
  }

  /// Queue an [action] that must be run only once per [key] while enqueued.
  /// Repeated calls with the same key will all share the same future and outcome.
  Future<T> runCoalesced<T>(Object key, Future<T> Function() action) {
    final pending = _coalesced[key];
    if (pending != null) return pending as Future<T>;
    if (_closed) return Future<T>.error(const SerialQueueClosed());

    final task = _QueueTask<T>(() async {
      try {
        return await action();
      } finally {
        _coalesced.remove(key);
      }
    });
    _coalesced[key] = task.result;

    _enqueue(task);
    return task.result;
  }

  /// Queue an [action] that must be run only once per [key] while enqueued.
  /// Repeated calls with the same key will fail with [InFlightError].
  Future<T> runUnique<T>(Object key, Future<T> Function() action) {
    if (_closed) return Future<T>.error(const SerialQueueClosed());
    if (!_inFlightKeys.add(key)) return Future<T>.error(InFlightError(key));

    final task = _QueueTask<T>(() async {
      try {
        return await action();
      } finally {
        _inFlightKeys.remove(key);
      }
    });

    _enqueue(task);
    return task.result;
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;

    const error = SerialQueueClosed();
    for (final task in _pending) {
      task.cancel(error);
    }
    _pending.clear();
    _coalesced.clear();
    _inFlightKeys.clear();

    if (_current == null) {
      _completeIdle();
      return;
    }

    await idle;
  }

  void _enqueue(_QueueEntry task) {
    _pending.add(task);
    _startNext();
  }

  void _startNext() {
    if (_current != null) return;

    if (_pending.isEmpty) {
      _completeIdle();
      return;
    }

    final task = _pending.removeAt(0);
    _current = task;
    unawaited(
      task.execute().whenComplete(() {
        _current = null;
        _startNext();
      }),
    );
  }

  void _completeIdle() {
    final idle = _idleCompleter;
    _idleCompleter = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }
}

abstract class _QueueEntry {
  Future<void> execute();

  void cancel(Object error);
}

class _QueueTask<T> implements _QueueEntry {
  _QueueTask(this._action);

  final Future<T> Function() _action;
  final _completer = Completer<T>();

  Future<T> get result => _completer.future;

  @override
  Future<void> execute() async {
    try {
      final value = await _action();
      if (!_completer.isCompleted) _completer.complete(value);
    } catch (error, stackTrace) {
      if (!_completer.isCompleted) _completer.completeError(error, stackTrace);
    }
  }

  @override
  void cancel(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
