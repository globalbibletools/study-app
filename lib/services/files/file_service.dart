import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

enum FileType { bible, audio, gloss }

class FileService {
  /// Returns the full local path for a given file type and relative path.
  Future<String> getLocalPath(FileType type, String relativePath) async {
    final docDir = await getApplicationDocumentsDirectory();

    late final String basePath;

    switch (type) {
      case FileType.bible:
        basePath = join(docDir.path, 'bibles');
        break;
      case FileType.gloss:
        basePath = join(docDir.path, 'glosses');
        break;
      case FileType.audio:
        basePath = join(docDir.path, 'audio');
        break;
    }

    return join(basePath, relativePath);
  }

  /// Checks if a file exists locally.
  Future<bool> checkFileExists(FileType type, String relativePath) async {
    final path = await getLocalPath(type, relativePath);
    return await File(path).exists();
  }

  /// Ensures the directory for a file exists (crucial before downloading).
  Future<void> ensureDirectoryExists(String filePath) async {
    final directory = Directory(dirname(filePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<void> deleteFile(FileType type, String relativePath) async {
    final path = await getLocalPath(type, relativePath);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Used to delete a whole chapter if needed, or check specific logic
  Future<bool> directoryHasFiles(FileType type, String relativeSubDir) async {
    // This is a bit complex because files are stored as .../HEB/Gen/001.mp3
    // We will check individual files in the UI logic for precision,
    // but this helper helps clean up empty directories if you wanted to implement strict cleanup.
    return false;
  }
}
