import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class EnglishDatabase {
  static const _databaseName = 'eng.db';
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
