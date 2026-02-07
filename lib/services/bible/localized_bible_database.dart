import 'dart:developer';

import 'package:database_builder/database_builder.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart';
import 'package:sqflite/sqflite.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';

class LocalizedBibleDatabase {
  final _fileService = getIt<FileService>();

  Database? _database;
  String _currentLangCode = '';

  /// Maps language codes to filenames.
  /// Update this map as you add support for more languages/versions.
  String getDbFilename(String langCode) {
    switch (langCode) {
      case 'es':
        return 'spa_blm.db';
      // case 'fr':
      //   return 'fra_lsg.db';
      // Default fallback
      default:
        return '$langCode.db';
    }
  }

  Future<bool> bibleDbExists(String langCode) async {
    final filename = getDbFilename(langCode);
    // You will need to ensure FileType.bible is added to your FileService enum
    return _fileService.checkFileExists(FileType.bible, filename);
  }

  Future<void> initDb(String langCode) async {
    if (_currentLangCode == langCode && _database != null) return;

    final filename = getDbFilename(langCode);
    final exists = await _fileService.checkFileExists(FileType.bible, filename);

    if (!exists) {
      log('Bible database for $langCode does not exist at $filename');
      return;
    }

    if (_database != null) {
      await _database?.close();
      _database = null;
      _currentLangCode = '';
    }

    final path = await _fileService.getLocalPath(FileType.bible, filename);

    try {
      _database = await openDatabase(path, readOnly: true);
      _currentLangCode = langCode;
      log('Opened localized bible: $filename');
    } catch (e) {
      log("Error opening localized bible DB: $e");
    }
  }

  Future<List<UsfmLine>> getChapter(
    String langCode,
    int bookId,
    int chapter,
  ) async {
    // Ensure DB is open for this language
    if (_database == null || _currentLangCode != langCode) {
      await initDb(langCode);
    }

    if (_database == null) return [];

    try {
      final (lowerBound, upperBound) = _chapterBounds(bookId, chapter);

      final verses = await _database!.query(
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
    } catch (e, s) {
      log('Error getting bible text for $langCode', error: e, stackTrace: s);
      return [];
    }
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
