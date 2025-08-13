import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:studyapp/common/verse_line.dart';

class BibleDatabase {
  static const _databaseName = 'eng_bsb.db';
  static const _databaseVersion = 1;
  late Database _database;

  Future<void> init() async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, _databaseName);
    var exists = await databaseExists(path);

    if (!exists) {
      log('Creating new copy of $_databaseName from assets');
      await _copyDatabaseFromAssets(path);
    } else {
      // Check if database needs update
      var currentVersion = await _getDatabaseVersion(path);
      if (currentVersion != _databaseVersion) {
        log(
          'Updating $_databaseName from version $currentVersion to $_databaseVersion',
        );
        await deleteDatabase(path);
        await _copyDatabaseFromAssets(path);
      } else {
        log("Opening existing $_databaseName database");
      }
    }
    _database = await openDatabase(path, version: _databaseVersion);
  }

  Future<int> _getDatabaseVersion(String path) async {
    var db = await openDatabase(path);
    var version = await db.getVersion();
    await db.close();
    return version;
  }

  Future<void> _copyDatabaseFromAssets(String path) async {
    await Directory(dirname(path)).create(recursive: true);
    final data = await rootBundle.load(join('assets/databases', _databaseName));
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<List<VerseLine>> getChapter(int bookId, int chapter) async {
    try {
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

      final List<Map<String, dynamic>> verses = await _database.rawQuery(sql, [
        startId,
        endId,
      ]);

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
    } catch (e) {
      log('Failed to get chapter: $e');
      // Return an empty list if there's any error (e.g., db not found).
      return [];
    }
  }
}
