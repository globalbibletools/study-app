import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/console_log_writer.dart';
import 'package:gbt/services/logging/file_log_writer.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/logging/log_directory.dart';
import 'package:gbt/services/logging/log_exporter.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/logging/log_writer.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AppLogger', () {
    late Directory tempDir;
    late LogDirectory logDirectory;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('app_logger_test_');
    });

    tearDown(() async {
      if (getIt.isRegistered<AppLogger>()) {
        await getIt<AppLogger>().dispose();
      }
      await getIt.reset();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<AppLogger> buildLogger({
      DateTime Function()? clock,
      String? directoryPath,
      List<LogWriter>? writers,
    }) async {
      logDirectory = await LogDirectory.create(
        path: directoryPath ?? tempDir.path,
      );
      final logger = AppLogger(
        clock: clock ?? () => DateTime.utc(2026, 10, 26, 12),
        writers: writers ?? [FileLogWriter(logDirectory), ConsoleLogWriter()],
      );
      getIt.registerSingleton<AppLogger>(logger);
      return logger;
    }

    File logFile(String date) => File(p.join(tempDir.path, '$date.jsonl'));

    test('logs entries to jsonl files for the current day', () async {
      final logger = await buildLogger();

      info('Today');
      await logger.flush();

      final file = logFile('2026-10-26');
      expect(await file.exists(), isTrue);

      final entry = await _readSingleEntry(file);
      expect(entry['timestamp'], '2026-10-26T12:00:00.000Z');
      expect(entry['level'], 'info');
      expect(entry['message'], 'Today');
    });

    test('creates the log directory when created', () async {
      final directoryPath = p.join(tempDir.path, 'nested', 'logs');
      final logger = await buildLogger(directoryPath: directoryPath);

      expect(await Directory(directoryPath).exists(), isTrue);

      info('Nested');

      await logger.flush();

      final file = File(p.join(directoryPath, '2026-10-26.jsonl'));
      expect(await file.exists(), isTrue);
    });

    test('appends to the current file across flushes', () async {
      final logger = await buildLogger();

      info('First');
      await logger.flush();
      info('Second');
      await logger.flush();

      final entries = await _readEntries(logFile('2026-10-26'));
      expect(entries.map((entry) => entry['message']), ['First', 'Second']);
    });

    test('uses UTC time to determine which file to write to', () async {
      var now = DateTime.parse('2026-10-26T23:30:00-05:00');
      final logger = await buildLogger(clock: () => now);

      info('Late local log');

      now = DateTime.utc(2026, 10, 27, 23, 59);
      info('Before midnight');

      now = DateTime.utc(2026, 10, 28, 0, 1);
      info('After midnight');

      await logger.flush();

      expect(await logFile('2026-10-26').exists(), isFalse);

      final firstFileEntries = await _readEntries(logFile('2026-10-27'));
      expect(firstFileEntries.map((entry) => entry['message']), [
        'Late local log',
        'Before midnight',
      ]);

      final secondFileEntries = await _readEntries(logFile('2026-10-28'));
      expect(secondFileEntries.map((entry) => entry['message']), [
        'After midnight',
      ]);
    });

    test('derives filename and scope from a class function', () async {
      final logger = await buildLogger();

      _TestLoggerHelper().logFromMethod();
      await logger.flush();

      final entry = await _readSingleEntry(logFile('2026-10-26'));
      expect(entry['filename'], 'app_logger_test.dart');
      expect(entry['scope'], contains('_TestLoggerHelper.logFromMethod'));
    });

    test('derives filename and scope from a function', () async {
      final logger = await buildLogger();

      _logFromFunction();
      await logger.flush();

      final entry = await _readSingleEntry(logFile('2026-10-26'));
      expect(entry['filename'], 'app_logger_test.dart');
      expect(entry['scope'], contains('_logFromFunction'));
    });

    test('derives filename and scope from an anonymous closure', () async {
      final logger = await buildLogger();

      _logFromNestedClosure();
      await logger.flush();

      final entry = await _readSingleEntry(logFile('2026-10-26'));
      expect(entry['filename'], 'app_logger_test.dart');
      expect(
        entry['scope'],
        contains('_logFromNestedClosure.<anonymous closure>'),
      );
    });

    test('logs errors with stack traces', () async {
      final logger = await buildLogger();

      _logWithError();
      await logger.flush();

      final entry = await _readSingleEntry(logFile('2026-10-26'));
      expect(entry['level'], 'error');
      expect(entry['message'], 'Failed');
      expect(entry['error'], contains('Bad state: boom'));
      expect(entry['stackTrace'], contains('_logWithError'));
    });

    test('level helpers set the log level automatically', () async {
      final logger = await buildLogger();

      debug('Debug message');
      info('Info message');
      warn('Warning message');
      error('Error message');
      await logger.flush();

      final entries = await _readEntries(logFile('2026-10-26'));
      expect(entries.map((entry) => entry['level']), [
        'debug',
        'info',
        'warning',
        'error',
      ]);
    });

    test('sends each log entry to every writer', () async {
      final first = _RecordingLogWriter();
      final second = _RecordingLogWriter();
      await buildLogger(writers: [first, second]);

      info('Both');

      expect(first.statements, hasLength(1));
      expect(second.statements, hasLength(1));
      expect(first.statements.single.message, 'Both');
    });

    test('zips the last 30 days of logs', () async {
      var now = DateTime.utc(2026, 9, 26, 12);
      final logger = await buildLogger(clock: () => now);

      for (var day = 0; day < 31; day++) {
        info('Day $day');
        now = now.add(const Duration(days: 1));
      }

      now = DateTime.utc(2026, 10, 26, 12);
      await logger.flush();
      final exporter = LogExporter(logDirectory);
      final bytes = await exporter.getExportAsBytes(now: now);
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((file) => file.name).toList();

      expect(names, hasLength(30));
      expect(names, isNot(contains('2026-09-26.jsonl')));
      expect(names, contains('2026-09-27.jsonl'));
      expect(names, contains('2026-10-26.jsonl'));
    });

    test('names the log zip with the current UTC timestamp', () {
      expect(
        LogExporter.exportFileNameForDate(DateTime.utc(2026, 10, 26, 12)),
        'gbt-logs-2026-10-26T12:00:00.000Z.zip',
      );
    });

    test('returns empty zip bytes when no logs are in range', () async {
      final logger = await buildLogger();
      await logger.flush();
      final exporter = LogExporter(logDirectory);

      expect(
        await exporter.getExportAsBytes(now: DateTime.utc(2026, 10, 26, 12)),
        isEmpty,
      );
    });
  });
}

Future<Map<String, dynamic>> _readSingleEntry(File file) async {
  final entries = await _readEntries(file);
  expect(entries, hasLength(1));
  return entries.single;
}

Future<List<Map<String, dynamic>>> _readEntries(File file) async {
  return (await file.readAsLines())
      .map((line) => jsonDecode(line) as Map<String, dynamic>)
      .toList();
}

class _TestLoggerHelper {
  void logFromMethod() {
    info('From class method');
  }
}

class _RecordingLogWriter implements LogWriter {
  final List<LogStatement> statements = <LogStatement>[];

  @override
  void write(LogStatement statement) {
    statements.add(statement);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

void _logFromFunction() {
  info('From function');
}

void _logFromNestedClosure() {
  (() {
    (() {
      info('From nested closure');
    })();
  })();
}

void _logWithError() {
  try {
    throw StateError('boom');
  } catch (e, stackTrace) {
    error('Failed', error: e, stackTrace: stackTrace);
  }
}
