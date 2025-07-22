// ignore_for_file: unused_element

import 'src/gloss/database.dart';
import 'src/hebrew_greek/database.dart';

Future<void> main(List<String> arguments) async {
  await _createHebrewGreekDatabase();
  // await _createGlossDatabase('spa');
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
