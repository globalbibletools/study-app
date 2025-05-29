import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class HebrewGreekDatabase {
  static const _databaseName = 'hebrew_greek.db';
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
        log('Updating database from version $currentVersion to $_databaseVersion');
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
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<List<HebrewGreekWord>> getChapter(int bookId, int chapter) async {
    const int bookMultiplier = 100000000;
    const int chapterMultiplier = 100000;
    final int lowerBound = bookId * bookMultiplier + chapter * chapterMultiplier;
    final int upperBound = bookId * bookMultiplier + (chapter + 1) * chapterMultiplier;

    final List<Map<String, dynamic>> words = await _database.rawQuery(
      'SELECT v.${HebrewGreekSchema.versesColId}, '
      't.${HebrewGreekSchema.textColText}, '
      'g.${HebrewGreekSchema.grammarColGrammar}, '
      'l.${HebrewGreekSchema.lemmaColLemma} '
      'FROM ${HebrewGreekSchema.versesTable} v '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON v.${HebrewGreekSchema.versesColText} = t.${HebrewGreekSchema.textColId} '
      'JOIN ${HebrewGreekSchema.grammarTable} g '
      'ON v.${HebrewGreekSchema.versesColGrammar} = g.${HebrewGreekSchema.grammarColId} '
      'JOIN ${HebrewGreekSchema.lemmaTable} l '
      'ON v.${HebrewGreekSchema.versesColLemma} = l.${HebrewGreekSchema.lemmaColId} '
      'WHERE v.${HebrewGreekSchema.versesColId} >= ? AND v.${HebrewGreekSchema.versesColId} < ? '
      'ORDER BY v.${HebrewGreekSchema.versesColId} ASC',
      [lowerBound, upperBound],
    );

    return words
        .map(
          (word) => HebrewGreekWord(
            id: word[HebrewGreekSchema.versesColId],
            text: word[HebrewGreekSchema.textColText],
            grammar: word[HebrewGreekSchema.grammarColGrammar],
            lemma: word[HebrewGreekSchema.lemmaColLemma],
          ),
        )
        .toList();
  }
}
