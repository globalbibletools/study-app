import 'package:database_builder/database_builder.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:gbt/common/reference.dart';

class BibleDatabase {
  final Database _database;

  BibleDatabase._(this._database);

  static Future<BibleDatabase> open(String path) async {
    final db = await openDatabase(path, readOnly: true);
    return BibleDatabase._(db);
  }

  Future<void> close() async => await _database.close();

  /// Retrieves multiple verses in batch queries.
  ///
  /// References are chunked into batches of $\le 500$ parameters to avoid
  /// exceeding SQLite variable limits. Section headers are excluded, and
  /// multi-line poetic lines for a single verse are concatenated with a space.
  Future<Map<Reference, String>> getVerses(List<Reference> references) async {
    if (references.isEmpty) return {};

    const excludedFormats = ['s', 's1', 's2', 'ms', 'mr', 'r', 'd', 'rem'];
    final formatPlaceholders = List.filled(
      excludedFormats.length,
      '?',
    ).join(',');
    final chunks = _chunkList(references, 500);
    final results = <Reference, String>{};

    for (final chunk in chunks) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final packedInts = chunk.map((r) => r.toPackedInt).toList();

      final rows = await _database.rawQuery(
        'SELECT ${BibleSchema.colReference}, ${BibleSchema.colText}, ${BibleSchema.colFormat} '
        'FROM ${BibleSchema.bibleTextTable} '
        'WHERE ${BibleSchema.colReference} IN ($placeholders) '
        'AND ${BibleSchema.colFormat} NOT IN ($formatPlaceholders) '
        'ORDER BY ${BibleSchema.colId} ASC',
        [...packedInts, ...excludedFormats],
      );

      for (final row in rows) {
        final packed = row[BibleSchema.colReference] as int;
        final ref = Reference.fromPackedInt(packed);
        final rawText = row[BibleSchema.colText] as String;
        final cleanText = stripParatext(rawText);
        if (cleanText.isEmpty) continue;
        if (results.containsKey(ref)) {
          results[ref] = '${results[ref]} $cleanText';
        } else {
          results[ref] = cleanText;
        }
      }
    }

    return results;
  }

  static final _footnoteRegex = RegExp(r'\\(f|fe|x)\b[\s\S]*?\\(f|fe|x)\*');
  static final _tagRegex = RegExp(r'\\[a-zA-Z0-9]+(\*)?');
  static final _whitespaceRegex = RegExp(r'\s+');

  /// Strips footnotes (\f ...\f*), endnotes (\fe ...\fe*), cross references
  /// (\x ...\x*), and USFM character tags (\add, \wj*, etc.), normalizing whitespace.
  static String stripParatext(String usfm) {
    var content = usfm.replaceAll(_footnoteRegex, '');
    content = content.replaceAll(_tagRegex, '');
    return content.replaceAll(_whitespaceRegex, ' ').trim();
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

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
