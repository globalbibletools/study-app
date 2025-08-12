import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:studyapp/ui/home/bible_panel/verse_line.dart';

class BibleDatabase {
  Database? _database;

  static const _path = 'bibles/eng_bsb.db';

  Future<String> _getDbPath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, _path);
  }

  Future<bool> bibleExists() async {
    final path = await _getDbPath();
    return databaseExists(path);
  }

  Future<void> init() async {
    final path = await _getDbPath();
    if (!await File(path).exists()) {
      log('Bible database does not exist at $path');
      return;
    }

    if (_database != null) {
      await _database?.close();
      _database = null;
    }

    _database = await openDatabase(path, readOnly: true);
  }

  Future<List<VerseLine>> getChapter(int bookId, int chapter) async {
    if (_database == null) {
      await init();
    }

    final int startId = bookId * 1000000 + chapter * 1000;
    final int endId = bookId * 1000000 + (chapter + 1) * 1000;

    final String sql = '''
    SELECT
      ${BibleSchema.colId},
      ${BibleSchema.colVerseId},
      ${BibleSchema.colText},
      ${BibleSchema.colType},
      ${BibleSchema.colFormat},
      ${BibleSchema.colFootnote}
    FROM
      ${BibleSchema.bibleTextTable}
    WHERE
      ${BibleSchema.colVerseId} >= ? AND ${BibleSchema.colVerseId} < ?
    ORDER BY
      ${BibleSchema.colVerseId}
  ''';

    // Execute the raw query
    final List<Map<String, dynamic>> verses = await _database!.rawQuery(sql, [
      startId,
      endId,
    ]);

    // final verses = await _database.query(
    //   BibleSchema.bibleTextTable,
    //   columns: [
    //     BibleSchema.colVerse,
    //     BibleSchema.colText,
    //     BibleSchema.colFootnote,
    //     BibleSchema.colType,
    //     BibleSchema.colFormat,
    //   ],
    //   where: '${BibleSchema.colBookId} = ? AND ${BibleSchema.colChapter} = ?',
    //   whereArgs: [bookId, chapter],
    //   orderBy: '${BibleSchema.colId} ASC',
    // );

    return verses.map((verse) {
      final format = verse[BibleSchema.colFormat] as int?;
      final verseNumber = (verse[BibleSchema.colVerseId] as int) % 1000;
      return VerseLine(
        bookId: bookId,
        chapter: chapter,
        verse: verseNumber,
        text: verse[BibleSchema.colText] as String,
        footnote: verse[BibleSchema.colFootnote] as String?,
        format: (format == null) ? null : Format.fromInt(format),
        type: TextType.fromInt(verse[BibleSchema.colType] as int),
      );
    }).toList();
  }
}
