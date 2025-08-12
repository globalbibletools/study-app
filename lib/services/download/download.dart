import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';

class DownloadService {
  final HttpClient _httpClient = HttpClient();

  Future<void> download({
    required String url,
    required String downloadTo,
    void Function(double)? onProgress,
  }) async {
    try {
      final appDocumentsDir = await getApplicationDocumentsDirectory();
      final zipPath = '${appDocumentsDir.path}/temp.zip';
      final zipFile = File(zipPath);

      // Create the destination directory if it doesn't exist
      final destinationDir = Directory('${appDocumentsDir.path}/$downloadTo');
      print(destinationDir.path);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      // Make the HTTP request and download the file
      final request = await _httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final totalBytes = response.contentLength;
        int receivedBytes = 0;
        final IOSink fileSink = zipFile.openWrite();

        await response
            .listen(
              (List<int> chunk) {
                fileSink.add(chunk);
                receivedBytes += chunk.length;
                if (onProgress != null && totalBytes != -1) {
                  final progress = receivedBytes / totalBytes;
                  onProgress(progress);
                }
              },
              onDone: () async {
                await fileSink.close();
              },
              onError: (e) {
                fileSink.close();
                throw e;
              },
              cancelOnError: true,
            )
            .asFuture();

        // Unzip
        debugPrint('Starting to extract archive...');
        final inputStream = InputFileStream(zipPath);
        final archive = ZipDecoder().decodeStream(inputStream);
        extractArchiveToDisk(archive, destinationDir.path);
        await inputStream.close();
        debugPrint('Extraction complete.');
        await zipFile.delete();
      } else {
        throw HttpException('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error during download and unzip: $e');
      rethrow;
    }
  }

  Future<bool> fileExists(String path) async {
    final appDocumentsDir = await getApplicationDocumentsDirectory();
    final file = File('${appDocumentsDir.path}/$path');
    print(file.path);
    return await file.exists();
  }
}
