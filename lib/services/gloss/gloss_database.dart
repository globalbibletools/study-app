import 'dart:developer';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:database_builder/database_builder.dart';
import 'package:http/http.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class GlossDatabase {
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
