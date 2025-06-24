import 'dart:developer';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
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
        log(
          'Updating database from version $currentVersion to $_databaseVersion',
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

  Future<List<HebrewGreekWord>> getChapter(int bookId, int chapter) async {
    const int bookMultiplier = 100000000;
    const int chapterMultiplier = 100000;
    final int lowerBound =
        bookId * bookMultiplier + chapter * chapterMultiplier;
    final int upperBound =
        bookId * bookMultiplier + (chapter + 1) * chapterMultiplier;

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

class EnglishDatabase {
  static const _databaseName = 'eng.db';
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
          'Updating database from version $currentVersion to $_databaseVersion',
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

  Future<String?> getGloss(int wordId) async {
    final List<Map<String, dynamic>> words = await _database.rawQuery(
      'SELECT v.${GlossSchema.versesColText}, '
      't.${GlossSchema.textColText} '
      'FROM ${GlossSchema.versesTable} v '
      'JOIN ${GlossSchema.textTable} t '
      'ON v.${GlossSchema.versesColText} = t.${GlossSchema.textColId} '
      'WHERE v.${GlossSchema.versesColId} == ?',
      [wordId],
    );
    if (words.isEmpty) {
      return null;
    }
    return words.first[GlossSchema.textColText];
  }
}

class GlossService {
  Database? _database;
  String _currentLangCode = '';

  static const _url =
      'https://github.com/globalbibletools/study-app/raw/refs/heads/main/temp/spa.db.zip';

  String _getDbName(String langCode) {
    switch (langCode) {
      case 'es':
        return 'spa.db';
      default:
        throw Exception('Unsupported language code: $langCode');
    }
  }

  Future<String> _getDbPath(String langCode) async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, _getDbName(langCode));
  }

  Future<bool> glossDbExists(String langCode) async {
    final path = await _getDbPath(langCode);
    return databaseExists(path);
  }

  Future<void> initDb(String langCode) async {
    if (_currentLangCode == langCode) {
      return;
    }

    final path = await _getDbPath(langCode);
    if (!await File(path).exists()) {
      log('Database for $langCode does not exist at $path');
      return;
    }

    if (_database != null) {
      await _database?.close();
      _database = null;
      _currentLangCode = '';
    }

    print('opening database');
    _database = await openDatabase(path, readOnly: true);
    _currentLangCode = langCode;
  }

  Future<String?> getGloss(String langCode, int wordId) async {
    try {
      final query = '''
        SELECT t.${GlossSchema.textColText}
        FROM ${GlossSchema.versesTable} v
        JOIN ${GlossSchema.textTable} t 
        ON v.${GlossSchema.versesColText} = t.${GlossSchema.textColId}
        WHERE v.${GlossSchema.versesColId} = ?
        ''';
      final List<Map<String, dynamic>> words = await _database!.rawQuery(
        query,
        [wordId],
      );
      if (words.isEmpty) return null;
      return words.first[GlossSchema.textColText] as String?;
    } catch (e, s) {
      log('Error getting gloss for $langCode', error: e, stackTrace: s);
      return null;
    }
  }

  Future<void> downloadAndInstallGlossDb(String langCode) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw Exception('No internet connection.');
    }

    final response = await get(Uri.parse(_url));

    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    final archive = ZipDecoder().decodeBytes(bytes);
    final archiveFile = archive.findFile('spa.db');

    if (archiveFile == null) {
      throw Exception('Database file not found in zip archive for $langCode.');
    }

    final dbPath = await _getDbPath(langCode);
    await File(
      dbPath,
    ).writeAsBytes(archiveFile.content as List<int>, flush: true);
    log('Successfully installed gloss database for $langCode');
  }
}
