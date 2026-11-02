import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:gbt/services/logging/caller.dart';
import 'package:gbt/services/logging/console_log_writer.dart';
import 'package:gbt/services/logging/file_log_writer.dart';
import 'package:gbt/services/logging/log_directory.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/logging/log_writer.dart';

class AppLogger {
  AppLogger({
    required DateTime Function() clock,
    required List<LogWriter> writers,
  }) : _clock = clock,
       _writers = writers;

  static Future<AppLogger> createDefault() async {
    final logDirectory = await LogDirectory.createDefault();
    return AppLogger(
      clock: DateTime.now,
      writers: [
        FileLogWriter(logDirectory),
        if (!kReleaseMode) ConsoleLogWriter(),
      ],
    );
  }

  final DateTime Function() _clock;
  final List<LogWriter> _writers;

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? filename,
    String? scope,
  }) {
    final caller = Caller.current();
    final statement = LogStatement(
      timestamp: _clock(),
      level: level,
      message: message,
      filename: filename ?? caller.filename,
      scope: scope ?? caller.scope,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    for (final writer in _writers) {
      try {
        writer.write(statement);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to write log entry',
          name: 'AppLogger',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> flush() async {
    for (final writer in _writers) {
      await writer.flush();
    }
  }

  Future<void> dispose() async {
    for (final writer in _writers) {
      await writer.close();
    }
  }
}
