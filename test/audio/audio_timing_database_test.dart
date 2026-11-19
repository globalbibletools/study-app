import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/audio/audio_timing.dart';
import 'package:gbt/audio/audio_timing_database.dart';

void main() {
  group('AudioTiming', () {
    test('verseNumber is the low three digits of verseId', () {
      expect(
        AudioTiming(verseId: 1001007, start: 1.0, end: 2.0).verseNumber,
        7,
      );
    });
  });

  group('AudioTimingDatabase', () {
    test('empty data has no chapters', () {
      final db = AudioTimingDatabase(Uint8List(0));

      expect(db.data, isEmpty);
      expect(db.getTimingsForChapter(0), isNull);
    });

    test('groups records by chapter and converts hundredths to seconds', () {
      final db = AudioTimingDatabase(
        _records([
          _Record(book: 1, chapter: 1, verse: 1, start: 0, end: 150),
          _Record(book: 1, chapter: 1, verse: 2, start: 150, end: 42),
          _Record(book: 1, chapter: 2, verse: 1, start: 0, end: 100),
        ]),
      );

      expect(db.data, hasLength(2));

      final chapter1 = db.getTimingsForChapter(0)!;
      expect(chapter1, hasLength(2));
      expect(chapter1[0].verseNumber, 1);
      expect(chapter1[0].start, 0);
      expect(chapter1[0].end, closeTo(1.5, 0.001));
      expect(chapter1[1].verseNumber, 2);
      expect(chapter1[1].start, closeTo(1.5, 0.001));
      expect(chapter1[1].end, closeTo(0.42, 0.001));

      final chapter2 = db.getTimingsForChapter(1)!;
      expect(chapter2, hasLength(1));
      expect(chapter2.single.verseNumber, 1);
      expect(chapter2.single.end, closeTo(1, 0.001));
    });

    test('treats the end sentinel as infinity', () {
      final db = AudioTimingDatabase(
        _records([
          _Record(book: 1, chapter: 1, verse: 1, start: 0, end: 0xFFFFFFFF),
        ]),
      );

      expect(db.data.single.single.end, double.infinity);
    });

    test('leaves empty chapters between recorded chapters', () {
      final db = AudioTimingDatabase(
        _records([
          _Record(book: 1, chapter: 1, verse: 1, start: 0, end: 100),
          _Record(book: 1, chapter: 3, verse: 1, start: 0, end: 100),
        ]),
      );

      expect(db.data, hasLength(3));
      expect(db.getTimingsForChapter(1), isEmpty);
      expect(db.getTimingsForChapter(2), hasLength(1));
      expect(db.getTimingsForChapter(3), isNull);
    });
  });
}

class _Record {
  const _Record({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.start,
    required this.end,
  });

  final int book;
  final int chapter;
  final int verse;
  final int start;
  final int end;
}

Uint8List _records(List<_Record> records) {
  final data = ByteData(records.length * 11);
  for (var i = 0; i < records.length; i++) {
    final record = records[i];
    final offset = i * 11;
    data.setUint8(offset, record.book);
    data.setUint8(offset + 1, record.chapter);
    data.setUint8(offset + 2, record.verse);
    data.setUint32(offset + 3, record.start);
    data.setUint32(offset + 7, record.end);
  }
  return data.buffer.asUint8List();
}
