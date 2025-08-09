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

  late Database _database;

  void init() {
    _database = sqlite3.open(output);
    _createTables();
  }

  void _createTables() {
    _database.execute(LexiconSchema.createStrongsTable);
    _database.execute(LexiconSchema.createGrammarTypesTable);
    _database.execute(LexiconSchema.createMeaningsTable);
  }

  void deleteDatabase() {
    final file = File(output);
    if (file.existsSync()) {
      print('Deleting database file: $output');
      file.deleteSync();
    }
  }

  Future<void> populateTables() async {
    final lemmaList = jsonDecode(await File(input).readAsString());
    final grammarMap = _populateGrammarTable(lemmaList);
    _populateStrongsTable(lemmaList);
    _populateMeaningTable(lemmaList, grammarMap);
    _createIndexes();
  }

  Map<String, int> _populateGrammarTable(List<dynamic> jsonData) {
    final grammarSet = <String>{};
    int missingGrammarCount = 0;
    int totalBaseForms = 0;
    for (final lemma in jsonData) {
      for (final baseForm in lemma['BaseForms']) {
        totalBaseForms++;
        final pos = baseForm['PartsOfSpeech'] as List?;
        final grammar = _joinList(pos);
        if (grammar == null || grammar.isEmpty) {
          missingGrammarCount++;
          continue;
        }
        grammarSet.add(grammar);
      }
    }

    print('BaseForms without PartOfSpeech: $missingGrammarCount');
    print('Total base forms: $totalBaseForms');
    print(grammarSet);

    final grammarMap = <String, int>{};
    final stmt = _database.prepare(
      'INSERT INTO ${LexiconSchema.grammarTable} '
      '(${LexiconSchema.grammarColText}) '
      'VALUES (?)',
    );
    for (final grammarText in grammarSet) {
      stmt.execute([grammarText]);
      grammarMap[grammarText] = _database.lastInsertRowId;
    }
    stmt.dispose();
    return grammarMap;
  }

  String? _joinList(List<dynamic>? pos) {
    if (pos == null) return null;
    final filteredList = pos.where((element) => element.isNotEmpty).toList();
    return filteredList.join(', ');
  }

  // Any Strong's code that is associated with a lemma should be mapped here.
  void _populateStrongsTable(List<dynamic> jsonData) {
    print('Populating Strong\'s table');

    final stmt = _database.prepare(
      'INSERT INTO ${LexiconSchema.strongsTable} '
      '(${LexiconSchema.strongsColStrongs}, '
      '${LexiconSchema.strongsColLemmaId}) '
      'VALUES (?, ?)',
    );

    for (final lemma in jsonData) {
      final lemmaId = int.parse(lemma['MainId']) ~/ LexiconSchema.lemmaIdOffset;
      final strongCodes = lemma['StrongCodes'] as List;
      for (final code in strongCodes) {
        if (code.isEmpty) continue;
        stmt.execute([code, lemmaId]);
      }
    }

    stmt.dispose();
  }

  void _populateMeaningTable(
    List<dynamic> jsonData,
    Map<String, int> grammarMap,
  ) {
    print('Populating Meaning table');

    final stmt = _database.prepare('''
    INSERT INTO ${LexiconSchema.meaningsTable} (
      ${LexiconSchema.meaningsColLexId},
      ${LexiconSchema.meaningsColGrammarId},
      ${LexiconSchema.meaningsColLemma},
      ${LexiconSchema.meaningsColDefinitionShort},
      ${LexiconSchema.meaningsColComments},
      ${LexiconSchema.meaningsColGlosses}
    ) VALUES (?, ?, ?, ?, ?, ?)
    ''');

    Map<String, dynamic>? debugLemma;
    try {
      _database.execute('BEGIN TRANSACTION');

      for (final lemmaData in jsonData) {
        final lemma = lemmaData['Lemma'] as String;
        debugLemma = lemmaData;
        for (final baseForm in lemmaData['BaseForms']) {
          final pos = baseForm['PartsOfSpeech'];
          final grammar = _joinList(pos);
          final grammarId = grammarMap[grammar];
          final lexMeanings = baseForm['LEXMeanings'] as List;
          for (final meaning in lexMeanings) {
            final lexId = int.parse(meaning['LEXID']);
            final senses = meaning['LEXSenses'] as List;
            for (final sense in senses) {
              final definitionShort = _clean(sense['DefinitionShort']);
              final comment = _clean(sense['Comments']);
              final glosses = _clean(_joinList(sense['Glosses']));
              if (glosses == null || glosses.isEmpty) continue;
              stmt.execute([
                lexId,
                grammarId,
                lemma,
                (definitionShort == null || definitionShort.isEmpty)
                    ? null
                    : definitionShort,
                (comment == null || comment.isEmpty) ? null : comment,
                glosses,
              ]);
            }
          }
        }
      }
      _database.execute('COMMIT');
    } catch (e) {
      print(e);
      print('lemmaData: $debugLemma');
      _database.execute('ROLLBACK');
    } finally {
      stmt.dispose();
    }
  }

  String? _clean(String? input) {
    if (input == null) return null;
    if (input == 'NO DATA YET') return null;
    String output = input.replaceAll('= ', '');
    return output.replaceAll('≈ ', '');
  }

  void _createIndexes() {
    _database.execute(LexiconSchema.createStrongsCodeIndex);
    _database.execute(LexiconSchema.createMeaningsLemmaIdIndex);
  }

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

// Hebrew example
// {
//   "MainId":000001000000000,
//   "Lemma":"אֵב",
//   "Version":5,
//   "HasAramaic":true,
//   "InLXX":false,
//   "AlphaPos":"א",
//   "StrongCodes":[
//     H0003,
//     A0004
//   ],
//   "Authors":[
//     "Reinier de Blois"
//   ],
//   "Contributors":[],
//   "AlternateLemmas":[],
//   "MainLinks":[],
//   "Notes":[],
//   "Localizations":null,
//   "Dates":null,
//   "ContributorNote":,
//   "BaseForms":[
//     {
//       "BaseFormID":000001001000000,
//       "PartsOfSpeech":[
//         "nsm"
//       ],
//       "Inflections":null,
//       "Constructs":null,
//       "Etymologies":null,
//       "RelatedLemmas":[
//         {
//           "Word":,
//           "Meanings":[]
//         }
//       ],
//       "RelatedNames":null,
//       "MeaningsOfName":null,
//       "CrossReferences":null,
//       "BaseFormLinks":[],
//       "LEXMeanings":[
//         {
//           "LEXID":000001001001000,
//           "LEXIsBiblicalTerm":"M",
//           "LEXEntryCode":,
//           "LEXIndent":0,
//           "LEXDomains":[
//             {
//               "DomainCode":001003,
//               "DomainSource":null,
//               "DomainSourceCode":null,
//               "Domain":"Vegetation"
//             }
//           ],
//           "LEXSubDomains":null,
//           "LEXForms":null,
//           "LEXValencies":null,
//           "LEXCollocations":null,
//           "LEXSynonyms":null,
//           "LEXAntonyms":null,
//           "LEXCrossReferences":null,
//           "LEXSenses":[
//             {
//               "LanguageCode":"en",
//               "LastEdited":"2020-05-18 16":"00":24,
//               "LastEditedBy":,
//               "DefinitionLong":,
//               "DefinitionShort":"= part of a plant or tree that is typically surrounded by brightly colored petals and will eventually develop into a fruit",
//               "Glosses":[
//                 "blossom",
//                 "flower"
//               ],
//               "Comments":
//             }
//           ],
//           "LEXIllustrations":null,
//           "LEXReferences":[
//             02200601100016
//           ],
//           "LEXLinks":null,
//           "LEXImages":null,
//           "LEXVideos":[],
//           "LEXCoordinates":null,
//           "LEXCoreDomains":[
//             {
//               "DomainCode":125,
//               "DomainSource":null,
//               "DomainSourceCode":null,
//               "Domain":"Plant"
//             }
//           ],
//           "CONMeanings":null
//         },
//         {
//           "LEXID":000001001002000,
//           "LEXIsBiblicalTerm":"M",
//           "LEXEntryCode":,
//           "LEXIndent":0,
//           "LEXDomains":[
//             {
//               "DomainCode":002001001057,
//               "DomainSource":"Vegetation",
//               "DomainSourceCode":001003,
//               "Domain":"Stage"
//             }
//           ],
//           "LEXSubDomains":null,
//           "LEXForms":null,
//           "LEXValencies":null,
//           "LEXCollocations":[
//             "בְּאֵב"
//           ],
//           "LEXSynonyms":null,
//           "LEXAntonyms":null,
//           "LEXCrossReferences":null,
//           "LEXSenses":[
//             {
//               "LanguageCode":"en",
//               "LastEdited":"2017-03-19 12":"46":16,
//               "LastEditedBy":,
//               "DefinitionLong":,
//               "DefinitionShort":"= state in which a plant or tree has developed blossoms",
//               "Glosses":[
//                 "blossom"
//               ],
//               "Comments":
//             }
//           ],
//           "LEXIllustrations":null,
//           "LEXReferences":[
//             01800801200006
//           ],
//           "LEXLinks":null,
//           "LEXImages":null,
//           "LEXVideos":[],
//           "LEXCoordinates":null,
//           "LEXCoreDomains":[
//             {
//               "DomainCode":125,
//               "DomainSource":null,
//               "DomainSourceCode":null,
//               "Domain":"Plant"
//             }
//           ],
//           "CONMeanings":null
//         },
//         {
//           "LEXID":000001001003000,
//           "LEXIsBiblicalTerm":"M",
//           "LEXEntryCode":,
//           "LEXIndent":0,
//           "LEXDomains":[
//             {
//               "DomainCode":001004003004,
//               "DomainSource":"Vegetation",
//               "DomainSourceCode":001003,
//               "Domain":"Fruits"
//             }
//           ],
//           "LEXSubDomains":null,
//           "LEXForms":null,
//           "LEXValencies":null,
//           "LEXCollocations":null,
//           "LEXSynonyms":null,
//           "LEXAntonyms":null,
//           "LEXCrossReferences":null,
//           "LEXSenses":[
//             {
//               "LanguageCode":"en",
//               "LastEdited":"2020-05-18 16":"00":24,
//               "LastEditedBy":,
//               "DefinitionLong":,
//               "DefinitionShort":"= part of a plant or tree that carries the seed and is often edible",
//               "Glosses":[
//                 "fruit"
//               ],
//               "Comments":
//             }
//           ],
//           "LEXIllustrations":null,
//           "LEXReferences":[
//             02700400900008,
//             02700401100032,
//             02700401800010
//           ],
//           "LEXLinks":null,
//           "LEXImages":null,
//           "LEXVideos":[],
//           "LEXCoordinates":null,
//           "LEXCoreDomains":[
//             {
//               "DomainCode":125,
//               "DomainSource":null,
//               "DomainSourceCode":null,
//               "Domain":"Plant"
//             }
//           ],
//           "CONMeanings":null
//         }
//       ]
//     }
//   ]
// }
