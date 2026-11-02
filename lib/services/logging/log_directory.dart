import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogDirectory {
  LogDirectory._(this._directory);

  static const _fileExtension = 'jsonl';

  final Directory _directory;

  static Future<LogDirectory> createDefault() async {
    final documents = await getApplicationDocumentsDirectory();
    return create(path: p.join(documents.path, 'logs'));
  }

  static Future<LogDirectory> create({required String path}) async {
    final directory = Directory(path);
    await directory.create(recursive: true);
    return LogDirectory._(directory);
  }

  File getFileForDate(DateTime date) {
    return File(p.join(_directory.path, _fileNameForDate(date)));
  }

  Future<List<File>> listFiles({
    required DateTime start,
    required DateTime end,
  }) async {
    final startFileName = _fileNameForDate(start);
    final endFileName = _fileNameForDate(end);

    final files = await _directory
        .list()
        .where(
          (entity) =>
              entity is File && entity.path.endsWith('.$_fileExtension'),
        )
        .cast<File>()
        .where((file) {
          final name = p.basename(file.path);
          return name.compareTo(startFileName) >= 0 &&
              name.compareTo(endFileName) <= 0;
        })
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String _fileNameForDate(DateTime date) {
    final utc = date.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '$year-$month-$day.$_fileExtension';
  }
}
