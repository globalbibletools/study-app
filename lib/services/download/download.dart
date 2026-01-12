import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';

class DownloadService {
  final HttpClient _httpClient = HttpClient();
  final _fileService = getIt<FileService>();

  /// Downloads a file from [url].
  ///
  /// [type]: Determines the base folder (gloss, audio, etc).
  /// [relativePath]: The path inside that base folder (e.g. 'HEB/Gen/001.mp3').
  /// [isZip]: If true, unzips the content into the parent directory of the target.
  Future<void> downloadFile({
    required String url,
    required FileType type,
    required String relativePath,
    bool isZip = false,
    void Function(double)? onProgress,
  }) async {
    try {
      final localPath = await _fileService.getLocalPath(type, relativePath);

      // Ensure the target folder exists
      await _fileService.ensureDirectoryExists(localPath);

      // If zipped, download to a temp file first. If not, download directly to path.
      final downloadTarget = isZip ? '$localPath.temp.zip' : localPath;
      final file = File(downloadTarget);

      // Network Request
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to download: ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final IOSink fileSink = file.openWrite();

      await response
          .listen(
            (List<int> chunk) {
              fileSink.add(chunk);
              receivedBytes += chunk.length;
              if (onProgress != null && totalBytes != -1) {
                onProgress(receivedBytes / totalBytes);
              }
            },
            onDone: () async => await fileSink.close(),
            onError: (e) {
              fileSink.close();
              throw e;
            },
            cancelOnError: true,
          )
          .asFuture();

      // Handle Unzipping
      if (isZip) {
        debugPrint('Extracting archive...');
        final inputStream = InputFileStream(downloadTarget);
        final archive = ZipDecoder().decodeStream(inputStream);

        // Extract to the directory containing the file
        final extractDir = File(localPath).parent.path;
        extractArchiveToDisk(archive, extractDir);

        await inputStream.close();
        await file.delete(); // Delete temp zip
        debugPrint('Extraction complete.');
      }
    } catch (e) {
      debugPrint('Error downloading $url: $e');
      rethrow;
    }
  }
}
