import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gbt/services/logging/log_directory.dart';
import 'package:path/path.dart' as p;

class LogExporter {
  LogExporter(this._logDirectory);

  static Future<LogExporter> createDefault() async {
    return LogExporter(await LogDirectory.createDefault());
  }

  static const exportDays = 30;

  final LogDirectory _logDirectory;

  static String exportFileNameForDate(DateTime date) =>
      'gbt-logs-${date.toUtc().toIso8601String()}.zip';

  Future<Uint8List> getExportAsBytes({
    required DateTime now,
    int days = exportDays,
  }) async {
    assert(days > 0);

    final utcNow = now.toUtc();
    final firstDate = DateTime.utc(
      utcNow.year,
      utcNow.month,
      utcNow.day,
    ).subtract(Duration(days: days - 1));
    final archive = Archive();

    for (final file in await _logDirectory.listFiles(
      start: firstDate,
      end: utcNow,
    )) {
      final name = p.basename(file.path);
      archive.addFile(ArchiveFile.bytes(name, await file.readAsBytes()));
    }

    if (archive.isEmpty) {
      return Uint8List(0);
    }

    return ZipEncoder().encodeBytes(archive, modified: utcNow);
  }
}
