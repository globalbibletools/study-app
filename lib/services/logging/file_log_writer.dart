import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:gbt/services/logging/log_directory.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/logging/log_writer.dart';

class FileLogWriter implements LogWriter {
  FileLogWriter(this._logDirectory);

  final List<LogStatement> _queue = <LogStatement>[];
  Future<void>? _drainFuture;

  final LogDirectory _logDirectory;
  IOSink? _currentSink;
  DateTime? _currentFileEndUtc;

  @override
  void write(LogStatement statement) {
    _queue.add(statement);
    _startDraining();
  }

  @override
  Future<void> flush() async {
    while (_drainFuture != null || _queue.isNotEmpty) {
      _startDraining();
      final draining = _drainFuture;
      if (draining == null) {
        break;
      }
      await draining;
    }

    final sink = _currentSink;
    if (sink != null) {
      await sink.flush();
    }
  }

  @override
  Future<void> close() async {
    try {
      await flush();
    } finally {
      await _closeCurrentFile();
    }
  }

  void _startDraining() {
    if (_drainFuture != null || _queue.isEmpty) {
      return;
    }

    _drainFuture = _drain().whenComplete(() {
      _drainFuture = null;
      _startDraining();
    });
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final batch = List<LogStatement>.of(_queue);
      _queue.clear();
      try {
        await _writeBatch(batch);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to write log entries',
          name: 'FileLogWriter',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _writeBatch(List<LogStatement> statements) async {
    if (statements.isEmpty) {
      return;
    }

    for (final statement in statements) {
      final timestamp = statement.timestamp.toUtc();
      final currentEnd = _currentFileEndUtc;
      if (currentEnd == null || !timestamp.isBefore(currentEnd)) {
        final dayStart = DateTime.utc(
          timestamp.year,
          timestamp.month,
          timestamp.day,
        );
        final dayEnd = dayStart.add(const Duration(days: 1));

        await _closeCurrentFile();

        final file = _logDirectory.getFileForDate(dayStart);
        _currentSink = file.openWrite(mode: FileMode.append);
        _currentFileEndUtc = dayEnd;
      }
      _currentSink!.writeln(statement.toJsonLine());
    }

    await _currentSink?.flush();
  }

  Future<void> _closeCurrentFile() async {
    final sink = _currentSink;
    _currentSink = null;
    _currentFileEndUtc = null;
    if (sink != null) {
      await sink.close();
    }
  }
}
