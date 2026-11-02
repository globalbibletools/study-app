import 'dart:developer' as developer;

import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/logging/log_writer.dart';

class ConsoleLogWriter implements LogWriter {
  @override
  void write(LogStatement statement) {
    developer.log(
      statement.toJsonLine(),
      name: statement.scope,
      level: _developerLevel(statement.level),
      error: statement.error,
      stackTrace: statement.stackTrace == null
          ? null
          : StackTrace.fromString(statement.stackTrace!),
    );
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  int _developerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
