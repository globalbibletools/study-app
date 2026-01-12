import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:studyapp/services/download/cancel_token.dart'; // Import this
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';

class DownloadService {
  final HttpClient _httpClient = HttpClient();
  final _fileService = getIt<FileService>();

  Future<void> downloadFile({
    required String url,
    required FileType type,
    required String relativePath,
    bool isZip = false,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken, // Add this parameter
  }) async {
    File? tempFile;

    try {
      final localPath = await _fileService.getLocalPath(type, relativePath);
      await _fileService.ensureDirectoryExists(localPath);

      final downloadTarget = isZip ? '$localPath.temp.zip' : '$localPath.part';
      tempFile = File(downloadTarget);

      // Check cancellation before starting
      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Failed to download: ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final IOSink fileSink = tempFile.openWrite();

      StreamSubscription? subscription;
      final completer = Completer<void>();

      // Listen to cancellation to abort the stream immediately
      cancelToken?.addListener(() {
        if (!completer.isCompleted) {
          subscription?.cancel();
          fileSink.close();
          completer.completeError(DownloadCanceledException());
        }
      });

      subscription = response.listen(
        (List<int> chunk) {
          fileSink.add(chunk);
          receivedBytes += chunk.length;
          if (onProgress != null && totalBytes != -1) {
            onProgress(receivedBytes / totalBytes);
          }
        },
        onDone: () async {
          await fileSink.close();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          fileSink.close();
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      // Wait for stream to finish or be canceled
      await completer.future;

      // Unzipping / Finalizing
      if (isZip) {
        if (cancelToken?.isCancelled ?? false)
          throw DownloadCanceledException();

        debugPrint('Extracting archive...');
        final inputStream = InputFileStream(downloadTarget);
        final archive = ZipDecoder().decodeStream(inputStream);

        final extractDir = File(localPath).parent.path;
        extractArchiveToDisk(archive, extractDir);

        await inputStream.close();
      } else {
        // Rename .part to actual file name
        await tempFile.rename(localPath);
        // tempFile is now invalid, but that's okay as we renamed it
        tempFile = null;
      }
    } catch (e) {
      // Clean up temp files on error or cancel
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    } finally {
      if (isZip && tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
