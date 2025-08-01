// ignore_for_file: unused_element

import 'src/gloss/database.dart';
import 'src/hebrew_greek/database.dart';
import 'src/lexicon/database.dart';

Future<void> main(List<String> arguments) async {
  // await _createHebrewGreekDatabase();
  await _createLexiconDatabases();
  // await _createGlossDatabase('spa');
}

Future<void> _createLexiconDatabases() async {
  await _createHebrewLexicon();
  await _createGreekLexicon();
}

Future<void> _createHebrewLexicon() async {
  final dbHelper = LexiconDatabase(
    input: 'lib/src/lexicon/data/hebrew/UBSHebrewDic-v0.9.1-en.JSON',
    output: 'sdbh.db',
  );
  print('Deleting existing Semantic Dictionary of Biblical Hebrew database');
  dbHelper.deleteDatabase();

  print('Creating new Semantic Dictionary of Biblical Hebrew database');
  dbHelper.init();

  print('Populate Semantic Dictionary of Biblical Hebrew Tables');
  await dbHelper.populateTables();

  print('Dispose Semantic Dictionary of Biblical Hebrew database resources');
  dbHelper.dispose();
}

Future<void> _createGreekLexicon() async {
  final dbHelper = LexiconDatabase(
    input: 'lib/src/lexicon/data/greek/UBSGreekNTDic-v1.1-en.JSON',
    output: 'sdbg.db',
  );
  print('Deleting existing Semantic Dictionary of Biblical Greek database');
  dbHelper.deleteDatabase();

  print('Creating new Semantic Dictionary of Biblical Greek database');
  dbHelper.init();

  print('Populate Semantic Dictionary of Biblical Greek Tables');
  await dbHelper.populateTables();

  print('Dispose Semantic Dictionary of Biblical Greek database resources');
  dbHelper.dispose();
}

Future<void> _createHebrewGreekDatabase() async {
  final dbHelper = HebrewGreekDatabase();

  print('Deleting existing Hebrew/Greek database');
  dbHelper.deleteDatabase();

  print('Creating new Hebrew/Greek database');
  dbHelper.init();

  print('Populate Hebrew/Greek Tables');
  await dbHelper.populateHebrewGreekTables();

  print('Dispose Hebrew/Greek database resources');
  dbHelper.dispose();
}

Future<void> _createGlossDatabase(String languageIsoCode) async {
  final dbHelper = GlossDatabase(languageIsoCode: languageIsoCode);

  print('Deleting existing Gloss database');
  dbHelper.deleteDatabase();

  print('Creating new Gloss database');
  dbHelper.init();

  print('Populate Gloss Table');
  await dbHelper.populateGlossTable();

  print('Dispose Gloss database resources');
  dbHelper.dispose();
}
