import 'dart:developer';

import 'package:database_builder/database_builder.dart';
import 'package:sqflite/sqflite.dart';

class GlossResult {
  const GlossResult({required this.gloss, required this.isAiGenerated});

  final String gloss;
  final bool isAiGenerated;
}

class GlossDatabase {
  final Database _database;

  GlossDatabase._(this._database);

  static Future<GlossDatabase> open(String path) async {
    final db = await openDatabase(path, readOnly: true);
    return GlossDatabase._(db);
  }

  Future<void> close() async => await _database.close();

  Future<GlossResult?> getGloss(String wordId) async {
    try {
      final query =
          '''
        SELECT t.${GlossSchema.textColText} AS human_gloss,
               v.${GlossSchema.versesColAiGloss} AS ai_gloss
        FROM ${GlossSchema.versesTable} v
        LEFT JOIN ${GlossSchema.textTable} t 
        ON v.${GlossSchema.versesColText} = t.${GlossSchema.textColId}
        WHERE v.${GlossSchema.versesColWordId} = ?
        ''';
      final List<Map<String, dynamic>> words = await _database.rawQuery(query, [
        wordId,
      ]);
      if (words.isEmpty) return null;

      final humanGloss = words.first['human_gloss'] as String?;
      final aiGloss = words.first['ai_gloss'] as String?;

      if (humanGloss != null && humanGloss.isNotEmpty) {
        return GlossResult(gloss: humanGloss, isAiGenerated: false);
      }
      if (aiGloss != null && aiGloss.isNotEmpty) {
        return GlossResult(gloss: aiGloss, isAiGenerated: true);
      }
      return null;
    } catch (e, s) {
      log('Error getting gloss for wordId $wordId', error: e, stackTrace: s);
      rethrow;
    }
  }
}
