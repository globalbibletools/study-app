import 'src/database_helper.dart';
import 'src/english.dart';
import 'src/hebrew_greek.dart';

Future<void> main(List<String> arguments) async {
  final dbHelper = DatabaseHelper();

  print('Deleting existing database');
  dbHelper.deleteDatabase();

  print('Creating new database');
  dbHelper.init();

  print('Populate Hebrew Greek Table');
  await populateHebrewGreekTable(dbHelper);

  print('Populate English Table');
  await populateEnglishTable(dbHelper);

  print('Dispose database resources');
  dbHelper.dispose();
}
