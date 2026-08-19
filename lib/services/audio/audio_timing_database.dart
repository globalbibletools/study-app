import 'dart:io';
import 'dart:typed_data';

import 'audio_timing.dart';

class AudioTimingDatabase {
    static const int _endSentinel = 0xFFFFFFFF;

    final List<List<AudioTiming>> data;

    AudioTimingDatabase(Uint8List bytes)
        : data = _openBytes(bytes);

    static Future<AudioTimingDatabase> openFile(String filepath) async {
      final file = File(filepath);
      final bytes = await file.readAsBytes();
      return AudioTimingDatabase(bytes);
    }

    List<AudioTiming>? getTimingsForChapter(int chapter) {
        if (chapter < 0 || chapter >= data.length) return null;
        return data[chapter];
    }

    static List<List<AudioTiming>> _openBytes(Uint8List bytes) {
      final buffer = ByteData.sublistView(bytes);

      final stride = 11;
      final size = buffer.lengthInBytes ~/ stride;
      int offset = stride * size;

      if (size == 0) {
          return [];
      }

      final chapterCount = buffer.getUint8(size * stride - 10);
      final chapters = List<List<AudioTiming>>.filled(chapterCount, []);

      for (int chapter = chapterCount - 1; chapter >= 0; chapter--) {
        final verseCount = buffer.getUint8(offset - 9);
        offset -= stride * verseCount;

        chapters[chapter] = List<AudioTiming>.generate(verseCount, (int index) {
          final pos = offset + index * stride;

          final book = buffer.getUint8(pos);
          final chapter = buffer.getUint8(pos + 1);
          final verse = buffer.getUint8(pos + 2);
          final verseId = (book * 1000 + chapter) * 1000 + verse;

          final double start = buffer.getUint32(pos + 3) / 100;
          final int endRaw = buffer.getUint32(pos + 7);
          final double end = endRaw == _endSentinel
              ? double.infinity
              : endRaw / 100;

          return AudioTiming(
            verseId: verseId,
            start: start,
            end: end
          );
        });
      }

      return chapters;
    }
}
