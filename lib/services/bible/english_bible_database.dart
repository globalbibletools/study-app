import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart';
import 'package:sqflite/sqflite.dart';

class EnglishBibleDatabase {
  static const _databaseName = 'eng_bsb.db';
  static const _databaseVersion = 2;
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
