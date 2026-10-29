import 'dart:convert';

/// The severity of a [LogStatement].
enum LogLevel {
  debug('debug'),
  info('info'),
  warning('warning'),
  error('error');

  const LogLevel(this.value);

  final String value;

  static LogLevel fromJson(Object? value) {
    return LogLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => LogLevel.info,
    );
  }
}

/// A single structured log record stored as one line in a daily JSONL file.
class LogStatement {
  LogStatement({
    required DateTime timestamp,
    required this.level,
    required this.message,
    required this.filename,
    required this.scope,
    this.error,
    this.stackTrace,
  }) : timestamp = timestamp.toUtc();

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String filename;

  /// The class name and function where the log occurred.
  final String scope;

  final String? error;
  final String? stackTrace;

  Map<String, Object> toJson() {
    final json = <String, Object>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.value,
      'message': message,
      'filename': filename,
      'scope': scope,
    };
    if (error != null) {
      json['error'] = error!;
    }
    if (stackTrace != null) {
      json['stackTrace'] = stackTrace!;
    }
    return json;
  }

  String toJsonLine() => jsonEncode(toJson());

  static LogStatement fromJson(Map<String, dynamic> json) {
    return LogStatement(
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      level: LogLevel.fromJson(json['level']),
      message: json['message'] as String,
      filename: json['filename'] as String,
      scope: json['scope'] as String,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }
}
