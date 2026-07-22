import 'dart:developer';

import 'package:database_builder/database_builder.dart';
import 'package:sqflite/sqflite.dart';

class GlossDatabase {
  final Database _database;

  GlossDatabase._(this._database);

  static Future<GlossDatabase> open(String path) async {
    final db = await openDatabase(path, readOnly: true);
    return GlossDatabase._(db);
  }

  Future<void> close() async => await _database.close();

  Future<String?> getGloss(int wordId) async {
    try {
      final query = '''
        SELECT t.${GlossSchema.textColText}
        FROM ${GlossSchema.versesTable} v
        JOIN ${GlossSchema.textTable} t 
        ON v.${GlossSchema.versesColText} = t.${GlossSchema.textColId}
        WHERE v.${GlossSchema.versesColId} = ?
        ''';
      final List<Map<String, dynamic>> words = await _database.rawQuery(
        query,
        [wordId],
      );
      if (words.isEmpty) return null;
      return words.first[GlossSchema.textColText] as String?;
    } catch (e, s) {
      log('Error getting gloss for wordId $wordId', error: e, stackTrace: s);
      rethrow;
    }
  }
}
