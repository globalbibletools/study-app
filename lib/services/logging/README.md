# Logging Service

## Overview
Provides structured, daily rotating JSONL file and console logging across the application. Automatically derives caller source filenames and lexical scopes from stack traces, batches asynchronous filesystem writes, and exports rolling log archives as compressed zip archives.

## Interface
- [log.dart:debug]: Top-level function to record debug-severity log statements.
- [log.dart:info]: Top-level function to record informational log statements.
- [log.dart:warn]: Top-level function to record warning log statements.
- [log.dart:error]: Top-level function to record error log statements with optional error and stack trace objects.
- [app_logger.dart:AppLogger]: Central logger coordinating caller inspection, timestamp assignment, and dispatch to registered log writers.
- [app_logger.dart:AppLogger.createDefault]: Asynchronous factory configuring `FileLogWriter` and conditionally adding `ConsoleLogWriter` in non-release mode.
- [app_logger.dart:AppLogger.log]: Constructs a `LogStatement` and delivers it to all attached writers.
- [app_logger.dart:AppLogger.flush]: Flushes pending writes across all attached writers.
- [app_logger.dart:AppLogger.dispose]: Closes all writers and releases underlying file sinks.
- [log_statement.dart:LogLevel]: Enum defining severities: `debug`, `info`, `warning`, `error`.
- [log_statement.dart:LogStatement]: Structured record encapsulating timestamp, severity, message, origin filename, scope, and optional error/stack trace details.
- [log_writer.dart:LogWriter]: Interface for log dispatch targets with `write`, `flush`, and `close` contracts.
- [file_log_writer.dart:FileLogWriter]: Queuing writer that asynchronously flushes JSONL entries to daily UTC log files.
- [console_log_writer.dart:ConsoleLogWriter]: Writer dispatching formatted JSON statements to `dart:developer.log`.
- [log_directory.dart:LogDirectory]: Filesystem manager for `logs/` directory providing `YYYY-MM-DD.jsonl` date-based pathing and date range listing.
- [caller.dart:Caller]: Stack trace parser extracting the caller's source file and method scope while ignoring logging internal frames.
- [log_exporter.dart:LogExporter]: Compresses up to 30 days of daily log files into a zip archive byte array.

## Invariants
- All log timestamps are normalized to UTC (`timestamp.toUtc()`).
- File log rotation occurs at UTC day boundaries (`YYYY-MM-DD.jsonl`).
- Console logging is omitted in release mode (`kReleaseMode == true`).
- `Caller.current()` filters out stack frames containing `services/logging/`.

## Side Effects
- Appends log lines to disk files via `IOSink.writeln`.
- Emits runtime diagnostics to `dart:developer.log`.
- Queries `getApplicationDocumentsDirectory` for the log folder location.

## Verification
- Run: `flutter test`
