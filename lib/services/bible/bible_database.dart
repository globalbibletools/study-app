import 'package:database_builder/database_builder.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart';
import 'package:sqflite/sqflite.dart';

class BibleDatabase {
  final Database _database;

  BibleDatabase._(this._database);

  static Future<BibleDatabase> open(String path) async {
    final db = await openDatabase(path, readOnly: true);
    return BibleDatabase._(db);
  }

  Future<void> close() async => await _database.close();

  Future<List<UsfmLine>> getChapter(int bookId, int chapter) async {
    final (lowerBound, upperBound) = _chapterBounds(bookId, chapter);

    final verses = await _database.query(
      BibleSchema.bibleTextTable,
      columns: [
        BibleSchema.colReference,
        BibleSchema.colText,
        BibleSchema.colFormat,
      ],
      where:
          '${BibleSchema.colReference} >= ? AND ${BibleSchema.colReference} < ?',
      whereArgs: [lowerBound, upperBound],
      orderBy: '${BibleSchema.colId} ASC',
    );

    return verses.map((verse) {
      final format = verse[BibleSchema.colFormat] as String;
      return UsfmLine(
        bookChapterVerse: verse[BibleSchema.colReference] as int,
        text: verse[BibleSchema.colText] as String,
        format: ParagraphFormat.fromJson(format),
      );
    }).toList();
  }

  (int, int) _chapterBounds(int bookId, int chapter) {
    const int bookMultiplier = 1000000;
    const int chapterMultiplier = 1000;
    final int lowerBound =
        bookId * bookMultiplier + chapter * chapterMultiplier;
    final int upperBound =
        bookId * bookMultiplier + (chapter + 1) * chapterMultiplier;
    return (lowerBound, upperBound);
  }
}
