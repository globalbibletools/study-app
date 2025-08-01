import 'dart:io';
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

class LexiconDatabase {
  LexiconDatabase({required this.input, required this.output});

  /// path to the input JSON
  final String input;

  /// filename of the output database
  final String output;

  // final String _databaseName = "lexicon.db";
  late Database _database;

  void init() {
    _database = sqlite3.open(output);
    _createTables();
  }

  void deleteDatabase() {
    final file = File(output);
    if (file.existsSync()) {
      print('Deleting database file: $output');
      file.deleteSync();
    }
  }

  void _createTables() {
    _database.execute(LexiconSchema.createStrongsTable);
    _database.execute(LexiconSchema.createGrammarTypesTable);
    _database.execute(LexiconSchema.createMeaningsTable);
  }

  Future<void> populateTables() async {
    final lemmaList = jsonDecode(await File(input).readAsString());
    // final greekJson = jsonDecode(
    //   await File(
    //     'lib/src/lexicon/data/greek/UBSGreekNTDic-v1.1-en.JSON',
    //   ).readAsString(),
    // );

    //   final allData = [...hebrewJson, ...greekJson];

    final grammarMap = _populateGrammarTypes(lemmaList);

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

  Map<String, int> _populateGrammarTypes(List<dynamic> jsonData) {
    final grammarSet = <String>{};
    int missingGrammarCount = 0;
    int totalBaseForms = 0;
    for (final lemma in jsonData) {
      for (final baseForm in lemma['BaseForms']) {
        totalBaseForms++;
        final pos = baseForm['PartsOfSpeech'];
        if (pos == null) {
          missingGrammarCount++;
          continue;
        }
        for (final grammar in pos) {
          if (grammar.isEmpty) {
            missingGrammarCount++;
            continue;
          }
          grammarSet.add(grammar);
        }
      }
    }

    print('BaseForms without PartOfSpeech: $missingGrammarCount');
    print('Total base forms: $totalBaseForms');
    print(grammarSet);

    final grammarMap = <String, int>{};
    final stmt = _database.prepare(
      'INSERT INTO ${LexiconSchema.grammarTable} (${LexiconSchema.grammarColText}) VALUES (?)',
    );
    for (final grammarText in grammarSet) {
      stmt.execute([grammarText]);
      grammarMap[grammarText] = _database.lastInsertRowId;
    }
    stmt.dispose();
    return grammarMap;
  }

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

/// Example lemma data structure. Files are a JSON list of these objects.
// {
//   "MainId":"000001000000000",
//   "Lemma":"α",
//   "Version":"0",
//   "HasAramaic":false,
//   "InLXX":false,
//   "AlphaPos":"α",
//   "StrongCodes":[],
//   "Authors":[],
//   "Contributors":[],
//   "AlternateLemmas":[],
//   "MainLinks":[],
//   "Notes":[],
//   "Localizations":null,
//   "Dates":null,
//   "ContributorNote":"",
//   "BaseForms":[
//     {
//       "BaseFormID":"000001001000000",
//       "PartsOfSpeech":[
//         "noun nom"
//       ],
//       "Inflections":[
//         {
//           "Lemma":"α",
//           "BaseFormIndex":1,
//           "Form":"",
//           "Realizations":[],
//           "Comments":[
//             {
//               "LanguageCode":"en",
//               "Meaning":"indeclinable"
//             },
//             {
//               "LanguageCode":"zh-Hant",
//               "Meaning":"無語尾變化"
//             }
//           ]
//         }
//       ],
//       "Constructs":null,
//       "Etymologies":null,
//       "RelatedLemmas":null,
//       "RelatedNames":null,
//       "MeaningsOfName":null,
//       "CrossReferences":null,
//       "BaseFormLinks":[],
//       "LEXMeanings":[
//         {
//           "LEXID":"000001001001000",
//           "LEXIsBiblicalTerm":"Y",
//           "LEXEntryCode":"60.46",
//           "LEXIndent":0,
//           "LEXDomains":[
//             {
//               "DomainCode":"060",
//               "DomainSource":"",
//               "DomainSourceCode":"",
//               "Domain":"Number"
//             }
//           ],
//           "LEXSubDomains":[
//             {
//               "DomainCode":"060003",
//               "DomainSource":"",
//               "DomainSourceCode":"",
//               "Domain":"First, Second, Third, Etc. [Ordinals]"
//             }
//           ],
//           "LEXForms":null,
//           "LEXValencies":null,
//           "LEXCollocations":null,
//           "LEXSynonyms":null,
//           "LEXAntonyms":null,
//           "LEXCrossReferences":null,
//           "LEXSenses":[
//             {
//               "LanguageCode":"en",
//               "LastEdited":"2021-05-24 13:06:09",
//               "LastEditedBy":"",
//               "DefinitionLong":"",
//               "DefinitionShort":"first in a series involving time, space, or set",
//               "Glosses":[
//                 "first"
//               ],
//               "Comments":"Occurring only in titles of NT writings: πρὸς Κορινθίους α ‘First Letter to the Corinthians’; Ἰωάννου α ‘First Epistle of John.’"
//             }
//           ],
//           "LEXIllustrations":null,
//           "LEXReferences":[
//             "04600100000000",
//             "05200100000000",
//             "05400100000000",
//             "06000100000000",
//             "06200100000000"
//           ],
//           "LEXLinks":null,
//           "LEXImages":null,
//           "LEXVideos":[],
//           "LEXCoordinates":null,
//           "LEXCoreDomains":null,
//           "CONMeanings":null
//         }
//       ]
//     }
//   ]
// }
