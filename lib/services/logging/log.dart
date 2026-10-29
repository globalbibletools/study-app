import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/service_locator.dart';

void debug(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? filename,
  String? scope,
}) {
  _log(
    LogLevel.debug,
    message,
    error: error,
    stackTrace: stackTrace,
    filename: filename,
    scope: scope,
  );
}

void info(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? filename,
  String? scope,
}) {
  _log(
    LogLevel.info,
    message,
    error: error,
    stackTrace: stackTrace,
    filename: filename,
    scope: scope,
  );
}

void warn(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? filename,
  String? scope,
}) {
  _log(
    LogLevel.warning,
    message,
    error: error,
    stackTrace: stackTrace,
    filename: filename,
    scope: scope,
  );
}

void error(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? filename,
  String? scope,
}) {
  _log(
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
    filename: filename,
    scope: scope,
  );
}

void _log(
  LogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
  String? filename,
  String? scope,
}) {
  final logger = getIt.isRegistered<AppLogger>() ? getIt<AppLogger>() : null;
  logger?.log(
    level,
    message,
    error: error,
    stackTrace: stackTrace,
    filename: filename,
    scope: scope,
  );
}
