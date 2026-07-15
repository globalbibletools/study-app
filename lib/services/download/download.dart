import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';
import 'package:gbt/services/download/cancel_token.dart'; // Import this
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final HttpClient _httpClient = HttpClient();
  final _fileService = getIt<FileService>();

  Future<void> downloadAsset({
    required RemoteAsset asset,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    File? tempFile;

    try {
      final localPath = await _fileService.getLocalPath(
        asset.fileType,
        asset.localRelativePath,
      );

      await _fileService.ensureDirectoryExists(localPath);

      final downloadTarget = asset.isZip
          ? '$localPath.temp.zip'
          : '$localPath.part';
      tempFile = File(downloadTarget);

      // Check cancellation before starting
      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      final request = await _httpClient.getUrl(Uri.parse(asset.remoteUrl));
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
      if (asset.isZip) {
        if (cancelToken?.isCancelled ?? false) {
          throw DownloadCanceledException();
        }

        debugPrint('Extracting archive...');
        final inputStream = InputFileStream(downloadTarget);
        final archive = ZipDecoder().decodeStream(inputStream);

        final extractDir = File(localPath).parent.path;
        extractArchiveToDisk(archive, extractDir);

        await inputStream.close();
      } else {
        debugPrint('Attempting to rename temp file to: $localPath');

        // Rename .part to actual file name
        await tempFile.rename(localPath);

        final exists = await File(localPath).exists(); // <--- ADD THIS
        debugPrint('File renamed. Exists at $localPath? $exists');

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
      if (asset.isZip && tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> getFile({
    required String url,
    required String localRelativePath,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    final isZip = url.endsWith(".zip");
    File? tempFile;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localPath = join(docDir.path, localRelativePath);

      await _fileService.ensureDirectoryExists(localPath);

      final downloadTarget = isZip
          ? '$localPath.temp.zip'
          : '$localPath.part';
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
        if (cancelToken?.isCancelled ?? false) {
          throw DownloadCanceledException();
        }

        debugPrint('Extracting archive...');
        final inputStream = InputFileStream(downloadTarget);
        final archive = ZipDecoder().decodeStream(inputStream);

        final extractDir = File(localPath).parent.path;
        extractArchiveToDisk(archive, extractDir);

        await inputStream.close();
      } else {
        debugPrint('Attempting to rename temp file to: $localPath');

        // Rename .part to actual file name
        await tempFile.rename(localPath);

        final exists = await File(localPath).exists(); // <--- ADD THIS
        debugPrint('File renamed. Exists at $localPath? $exists');

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

  Future<List<T>> getJsonl<T>(
    String url, {
    required T Function(Map<String, dynamic> json) convert,
  }) async {
    final request = await _httpClient.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Failed to download: ${response.statusCode}');
    }

    final results = <T>[];

    final lines = response.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        results.add(convert(decoded));
      } else {
        throw FormatException(
          'Expected a JSON object on each line, got: ${decoded.runtimeType}',
        );
      }
    }

    return results;
  }
}
