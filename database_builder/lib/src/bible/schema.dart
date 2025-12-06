class BibleSchema {
  // Bible table
  static const String bibleTextTable = "bible";

  // BSB column names
  static const String colId = '_id';
  // BBCCCVVV packed integer
  static const String colReference = 'reference';
  static const String colText = 'text';
  // paragraph format
  static const String colFormat = 'format';

  // SQL statements
  static const String createBibleTextTable =
      '''
  CREATE TABLE IF NOT EXISTS $bibleTextTable (
    $colId INTEGER PRIMARY KEY AUTOINCREMENT,
    $colReference INTEGER NOT NULL,
    $colText TEXT NOT NULL,
    $colFormat TEXT NOT NULL
  )
  ''';

  static const String insertLine =
      '''
  INSERT INTO $bibleTextTable (
    $colReference, $colText, $colFormat
  ) VALUES (?, ?, ?)
  ''';
}
