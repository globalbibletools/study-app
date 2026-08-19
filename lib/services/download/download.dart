import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:gbt/services/download/cancel_token.dart'; // Import this
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:path/path.dart' as p;

class HttpNotFoundException implements Exception {
  final String url;
  HttpNotFoundException(this.url);

  @override
  String toString() => 'HttpNotFoundException: url=$url';
}

class DownloadService {
  final HttpClient _httpClient = HttpClient();
  final _fileService = getIt<FileService>();

  Future<Uint8List> getBytes(String url) async {
    final request = await _httpClient.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode == HttpStatus.notFound) {
      throw HttpNotFoundException(url);
    }
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download bytes: url=$url, statusCode=${response.statusCode}',
      );
    }

    final builder = BytesBuilder();
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<bool> checkExistence(String url) async {
    final request = await _httpClient.headUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode == HttpStatus.ok) {
        return true;
    } else if (response.statusCode == HttpStatus.notFound) {
        return false;
    } else {
        throw HttpException('Failed to check existence: ${response.statusCode}');
    }
  }

  Future<void> downloadFile({
    required String url,
    required String localPath,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    File? tempFile;

    try {
      await _fileService.ensureDirectoryExists(localPath);

      final downloadTarget = '$localPath.part';
      tempFile = File(downloadTarget);

      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      await _streamToFile(
        url: url,
        target: tempFile,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      debugPrint('Attempting to rename temp file to: $localPath');
      await tempFile.rename(localPath);
      tempFile = null;

      final exists = await File(localPath).exists();
      debugPrint('File renamed. Exists at $localPath? $exists');
    } catch (e) {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<void> downloadZip({
    required String url,
    required String localPath,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    Directory? extractDir;

    try {
      await _fileService.ensureDirectoryExists(localPath);
      final parent = p.dirname(localPath);
      final base = p.basename(localPath);
      final extractDirPath =
          p.join(parent, '.$base.extract-${DateTime.now().microsecondsSinceEpoch}');
      extractDir = await Directory(extractDirPath).create(recursive: true);
      final zipPath = p.join(extractDir.path, 'download.zip');

      debugPrint("Zip = $zipPath");
      debugPrint("Extract = $extractDirPath");

      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      await _streamToFile(
        url: url,
        target: File(zipPath),
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled ?? false) throw DownloadCanceledException();

      debugPrint('Extracting archive...');
      final inputStream = InputFileStream(zipPath);
      try {
        final archive = ZipDecoder().decodeStream(inputStream);
        extractArchiveToDisk(archive, extractDir.path);
      } finally {
        await inputStream.close();
      }

      final zipfile = File(zipPath);
      if (await zipfile.exists()) {
        await zipfile.delete();
      }
      
      final extracted = extractDir.listSync();
      if (extracted.length != 1) {
        throw FormatException(
          'Expected exactly one file or root directory in the zip, '
          'found ${extracted.length}.',
        );
      }

      final extractedEntity = extracted.first;

      final destFile = File(localPath);
      final destDir = Directory(localPath);
      if (await destFile.exists()) {
        await destFile.delete();
      } else if (await destDir.exists()) {
        await destDir.delete(recursive: true);
      }

      await extractedEntity.rename(localPath);
    } finally {
      if (extractDir != null && await extractDir.exists()) {
        await extractDir.delete(recursive: true);
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
      throw HttpException('Failed to download: url=$url, statusCode=${response.statusCode}');
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

  Future<void> _streamToFile({
    required String url,
    required File target,
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    final request = await _httpClient.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Failed to download: ${response.statusCode}');
    }

    final totalBytes = response.contentLength;
    int receivedBytes = 0;
    final IOSink fileSink = target.openWrite();

    StreamSubscription? subscription;
    final completer = Completer<void>();

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

    await completer.future;
  }
}
