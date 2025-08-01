import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

class LexiconDatabase {
  final String _databaseName = "lexicon.db";
  late Database _database;

  void init() {
    _database = sqlite3.open(_databaseName);
    _createTables();
  }

  void deleteDatabase() {
    final file = File(_databaseName);
    if (file.existsSync()) {
      print('Deleting database file: $_databaseName');
      file.deleteSync();
    }
  }

  void _createTables() {
    _database.execute(LexiconSchema.createStrongsMappingTable);
    _database.execute(LexiconSchema.createGrammarTypesTable);
    _database.execute(LexiconSchema.createMeaningsTable);
  }

  Future<void> populateTables() async {
  //   final hebrewJson = jsonDecode(
  //     await File(
  //       'lib/src/lexicon/data/hebrew/UBSHebrewDic-v0.9.1-en.JSON',
  //     ).readAsString(),
  //   );
  //   final greekJson = jsonDecode(
  //     await File(
  //       'lib/src/lexicon/data/greek/UBSGreekNTDic-v1.1-en.JSON',
  //     ).readAsString(),
  //   );

  //   final allData = [...hebrewJson, ...greekJson];

  //   final grammarMap = _populateGrammarTypes(allData);

  //   _database.execute('BEGIN TRANSACTION');

  //   final lemmasStmt = _database.prepare(
  //     'INSERT INTO ${LexiconSchema.lemmasTable} (${LexiconSchema.lemmasColMainId}, ${LexiconSchema.lemmasColLemmaText}) VALUES (?, ?)',
  //   );
  //   final strongsStmt = _database.prepare(
  //     'INSERT INTO ${LexiconSchema.strongsMappingTable} (${LexiconSchema.strongsMappingColStrongCode}, ${LexiconSchema.strongsMappingColLemmaId}) VALUES (?, ?)',
  //   );
  //   final meaningsStmt = _database.prepare('''
  //   INSERT INTO ${LexiconSchema.meaningsTable} 
  //   (${LexiconSchema.meaningsColLexId}, ${LexiconSchema.meaningsColLemmaId}, ${LexiconSchema.meaningsColGrammarId}, ${LexiconSchema.meaningsColLexEntryCode}, ${LexiconSchema.meaningsColDefinitionShort}, ${LexiconSchema.meaningsColComments}, ${LexiconSchema.meaningsColGlosses})
  //   VALUES (?, ?, ?, ?, ?, ?, ?)
  // ''');

  //   for (final lemmaObject in allData) {
  //     final mainId = int.tryParse(lemmaObject['MainId'] ?? '0') ?? 0;
  //     if (mainId == 0) continue;

  //     final existing = _database.select(
  //       'SELECT 1 FROM ${LexiconSchema.lemmasTable} WHERE ${LexiconSchema.lemmasColMainId} = ?',
  //       [mainId],
  //     );
  //     if (existing.isEmpty) {
  //       lemmasStmt.execute([mainId, lemmaObject['Lemma']]);
  //     }

  //     if (lemmaObject['StrongCodes'] != null) {
  //       for (final strongCode in lemmaObject['StrongCodes']) {
  //         strongsStmt.execute([strongCode, mainId]);
  //       }
  //     }

  //     if (lemmaObject['BaseForms'] != null) {
  //       for (final baseForm in lemmaObject['BaseForms']) {
  //         if (baseForm['PartsOfSpeech'] == null) continue;
  //         final grammarText =
  //             (baseForm['PartsOfSpeech'] as List).first ?? 'unknown';
  //         final grammarId = grammarMap[grammarText];
  //         if (grammarId == null) continue;

  //         if (baseForm['LEXMeanings'] != null) {
  //           for (final meaning in baseForm['LEXMeanings']) {
  //             if (meaning['LEXSenses'] != null &&
  //                 (meaning['LEXSenses'] as List).isNotEmpty) {
  //               final sense = (meaning['LEXSenses'] as List).first;
  //               final glosses = jsonEncode(sense['Glosses']);

  //               final existingMeaning = _database.select(
  //                 'SELECT 1 FROM ${LexiconSchema.meaningsTable} WHERE ${LexiconSchema.meaningsColLexId} = ?',
  //                 [int.parse(meaning['LEXID'])],
  //               );
  //               if (existingMeaning.isEmpty) {
  //                 meaningsStmt.execute([
  //                   int.parse(meaning['LEXID']),
  //                   mainId,
  //                   grammarId,
  //                   meaning['LEXEntryCode'],
  //                   sense['DefinitionShort'],
  //                   sense['Comments'],
  //                   glosses,
  //                 ]);
  //               }
  //             }
  //           }
  //         }
  //       }
  //     }
  //   }

  //   lemmasStmt.dispose();
  //   strongsStmt.dispose();
  //   meaningsStmt.dispose();

  //   _database.execute('COMMIT');

  //   _createIndexes();
  }

  // Map<String, int> _populateGrammarTypes(List<dynamic> jsonData) {
  //   final grammarSet = <String>{};
  //   for (final lemma in jsonData) {
  //     if (lemma['BaseForms'] != null) {
  //       for (final baseForm in lemma['BaseForms']) {
  //         if (baseForm['PartsOfSpeech'] != null &&
  //             (baseForm['PartsOfSpeech'] as List).isNotEmpty) {
  //           final grammar = (baseForm['PartsOfSpeech'] as List).first;
  //           if (grammar != null) {
  //             grammarSet.add(grammar);
  //           }
  //         }
  //       }
  //     }
  //   }

  //   final grammarMap = <String, int>{};
  //   final stmt = _database.prepare(
  //     'INSERT INTO ${LexiconSchema.grammarTypesTable} (${LexiconSchema.grammarTypesColGrammarText}) VALUES (?)',
  //   );
  //   for (final grammarText in grammarSet) {
  //     stmt.execute([grammarText]);
  //     grammarMap[grammarText] = _database.lastInsertRowId;
  //   }
  //   stmt.dispose();
  //   return grammarMap;
  // }

  // void _createIndexes() {
  //   _database.execute(
  //     'CREATE INDEX idx_strongs_mapping_strong_code ON ${LexiconSchema.strongsMappingTable}(${LexiconSchema.strongsMappingColStrongCode});',
  //   );
  //   _database.execute(
  //     'CREATE INDEX idx_meanings_lemma_id ON ${LexiconSchema.meaningsTable}(${LexiconSchema.meaningsColLemmaId});',
  //   );
  // }

  void dispose() {
    _database.dispose();
  }
}
