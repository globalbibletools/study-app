import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum FileType { bible, audio, gloss }

class FileService {
  /// Returns the full local path for a given file type and relative path.
  ///
  /// [relativePath] example:
  /// - Audio: 'HEB/Gen/001.mp3'
  /// - Database: 'eng_bsb.db'
  Future<String> getLocalPath(FileType type, String relativePath) async {
    String basePath;

    switch (type) {
      case FileType.bible:
      case FileType.gloss:
        // SQFLite expects databases here
        basePath = await getDatabasesPath();
      case FileType.audio:
        final docDir = await getApplicationDocumentsDirectory();
        basePath = join(docDir.path, 'audio');
    }

    return join(basePath, relativePath);
  }

  /// Checks if a file exists locally.
  Future<bool> checkFileExists(FileType type, String relativePath) async {
    final path = await getLocalPath(type, relativePath);
    final exists = File(path).exists(); // Note: check sync or await async

    // Check if it exists (awaiting the result if you use async exists, or File(path).existsSync())
    final doesExist = await File(path).exists();

    log('Checking existence for: $path -> $doesExist'); // <--- ADD THIS

    return doesExist;
  }

  /// Ensures the directory for a file exists (crucial before downloading).
  Future<void> ensureDirectoryExists(String filePath) async {
    final directory = Directory(dirname(filePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }
}
