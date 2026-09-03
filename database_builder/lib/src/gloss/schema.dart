class GlossSchema {
  // Gloss verses table
  //
  // Contains the content of the verses in Biblical order. However,
  // all of the words are encoded as integers that reference the text
  // table. This saves space because many words are repeated and integers
  // take up less space than strings.
  static const String versesTable = "verses";

  // The source word id (BBCCCVVVWW), e.g. "0100100101".
  static const String versesColWordId = 'word_id';
  // foreign key to the text table
  static const String versesColText = 'text';

  static const String createVersesTable = '''
  CREATE TABLE IF NOT EXISTS $versesTable (
    $versesColWordId TEXT PRIMARY KEY,
    $versesColText INTEGER
  )
  ''';

  static const insertVerseGloss = '''
  INSERT INTO $versesTable
    ($versesColWordId, $versesColText)
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

  static const String insertText = '''
  INSERT INTO $textTable
    ($textColId, $textColText)
    VALUES (?, ?);
  ''';
}
