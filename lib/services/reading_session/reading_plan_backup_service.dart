import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gbt/services/reading_session/rs_database.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ReadingSessionBackupInfo {
  const ReadingSessionBackupInfo({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;
}

class ReadingPlanBackupService {
  ReadingPlanBackupService() : _database = getIt<ReadingSessionDatabase>();

  ReadingPlanBackupService.withDatabase(this._database);

  static const _backupFormatVersion = 2;
  static const _backupDirectoryName = 'backups';
  static const _backupFilePrefix = 'reading_session_';

  final ReadingSessionDatabase _database;

  Future<String> createBackup() async {
    final backupDir = await _getBackupDirectory();
    await backupDir.create(recursive: true);

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = join(
      backupDir.path,
      '$_backupFilePrefix$timestamp.json',
    );

    return exportBackup(backupPath);
  }

  Future<String> exportBackup(String backupPath) async {
    final file = File(backupPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await buildBackupBytes(), flush: true);
    return file.path;
  }

  Future<Uint8List> buildBackupBytes() async {
    final payload = {
      'format_version': _backupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': await _database.exportBackupTables(),
    };
    final encoded = utf8.encode(jsonEncode(payload));
    return Uint8List.fromList(encoded);
  }

  Future<List<ReadingSessionBackupInfo>> listBackups() async {
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      return [];
    }

    final files = await backupDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final backups = <ReadingSessionBackupInfo>[];
    for (final file in files) {
      final stat = await file.stat();
      backups.add(
        ReadingSessionBackupInfo(
          path: file.path,
          name: basename(file.path),
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<void> restoreBackup(String backupPath) async {
    final file = File(backupPath);
    await restoreBackupJson(await file.readAsString());
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    await restoreBackupJson(utf8.decode(bytes));
  }

  Future<void> restoreBackupJson(String content) async {
    final raw = jsonDecode(content);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file.');
    }

    final tables = raw['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup is missing table data.');
    }

    final version = raw['format_version'];
    if (version is! int) {
      throw const FormatException('Backup is missing version data.');
    }

    await _database.restoreBackupTables(tables, formatVersion: version);
  }

  Future<Directory> _getBackupDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(join(docDir.path, _backupDirectoryName));
  }
}
