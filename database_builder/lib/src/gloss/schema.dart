class GlossSchema {
  // Gloss verses table
  //
  // Contains the content of the verses in Biblical order. However,
  // all of the words are encoded as integers that reference the text
  // table. This saves space because many words are repeated and integers
  // take up less space than strings.
  static const String versesTable = "verses";

  // ID is in the form of BBCCCVVVWW,
  // where BB is the book number,
  // CC is the chapter number,
  // VVV is the verse number,
  // and WW is the word number.
  static const String versesColId = '_id';
  // foreign key to the text table
  static const String versesColText = 'text';

  static const String createVersesTable = '''
  CREATE TABLE IF NOT EXISTS $versesTable (
    $versesColId INTEGER PRIMARY KEY,
    $versesColText INTEGER
  )
  ''';

  static const insertVerseGloss = '''
  INSERT INTO $versesTable
    ($versesColId, $versesColText)
    VALUES (?, ?);
  ''';

  // Gloss text table
  static const String textTable = 'text';

  static const String textColId = '_id';
  // This is the gloss word or phrase itself.
  static const String textColText = 'text';

  static const String createTextTable = '''
  CREATE TABLE IF NOT EXISTS $textTable (
    $textColId INTEGER PRIMARY KEY,
    $textColText TEXT NOT NULL
  )
  ''';

  static const insertText = '''
  INSERT INTO $textTable
    ($textColId, $textColText)
    VALUES (?, ?);
  ''';
}
