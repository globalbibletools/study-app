import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'audio_timing.dart';

class AudioDatabase {
  static const _databaseName = 'audio_timings.db';
  static const _databaseVersion =
      1; // Increment this if you regenerate the DB with new data

  // Table and Column constants match the builder schema
  static const _tableName = 'timings';
  static const _colVerseId = 'verse_id';
  static const _colRecordingId = 'recording_id';
  static const _colStart = 'start';
  static const _colEnd = 'end';

  late Database _database;

  Future<void> init() async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, _databaseName);
    var exists = await databaseExists(path);

    if (!exists) {
      log('Creating new copy of $_databaseName from assets');
      await _copyDatabaseFromAssets(path);
    } else {
      // Check if database needs update based on version
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
    // We open read-only just to check version
    var db = await openDatabase(path);
    var version = await db.getVersion();
    await db.close();
    return version;
  }

  Future<void> _copyDatabaseFromAssets(String path) async {
    await Directory(dirname(path)).create(recursive: true);

    // Ensure you have added 'assets/databases/audio_timings.db' to your pubspec.yaml
    final data = await rootBundle.load(join('assets/databases', _databaseName));

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  /// Retrieves timing data for a specific chapter and recording type.
  ///
  /// [bookId] - The integer ID of the book (e.g., 1 for Genesis)
  /// [chapter] - The chapter number
  /// [recordingId] - 'HEB' or 'RDB'
  Future<List<AudioTiming>> getTimingsForChapter(
    int bookId,
    int chapter,
    String recordingId,
  ) async {
    final (lowerBound, upperBound) = _chapterBounds(bookId, chapter);

    final results = await _database.query(
      _tableName,
      columns: [_colVerseId, _colStart, _colEnd],
      where: '$_colVerseId >= ? AND $_colVerseId < ? AND $_colRecordingId = ?',
      whereArgs: [lowerBound, upperBound, recordingId],
      orderBy: '$_colVerseId ASC',
    );

    return results.map((map) => AudioTiming.fromMap(map)).toList();
  }

  /// Calculates the verse_id range for a specific book/chapter
  /// Format: BBCCCVVV (e.g., Gen 1:1 -> 01001001)
  /// Note: The builder used `int.parse` on the CSV, so ensure leading zeros
  /// in the CSV didn't cause octal issues (usually fine in Dart/CSV).
  (int, int) _chapterBounds(int bookId, int chapter) {
    const int bookMultiplier = 1000000;
    const int chapterMultiplier = 1000;

    // Start of chapter: Book 01, Chapter 001, Verse 000
    final int lowerBound =
        bookId * bookMultiplier + chapter * chapterMultiplier;

    // Start of next chapter: Book 01, Chapter 002, Verse 000
    // This covers all verses in the current chapter
    final int upperBound =
        bookId * bookMultiplier + (chapter + 1) * chapterMultiplier;

    return (lowerBound, upperBound);
  }
}
