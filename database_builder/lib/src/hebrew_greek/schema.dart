class HebrewGreekSchema {
  // Hebrew/Greek verses table
  //
  // Contains the content of the verses in Biblical order. However,
  // all of the words are encoded as integers that reference other tables.
  // This saves space because many words are repeated and integers take up
  // less space than strings.
  static const versesTable = "verses";

  static const versesColId = '_id';
  static const versesColText = 'text'; // foreign key to text table
  static const versesColGrammar = 'grammar'; // foreign key to grammar table
  static const versesColLemma = 'lemma'; // foreign key to lemma table

  static const createVersesTable =
      '''
  CREATE TABLE IF NOT EXISTS $versesTable (
    $versesColId INTEGER PRIMARY KEY,
    $versesColText INTEGER NOT NULL,
    $versesColGrammar INTEGER NOT NULL,
    $versesColLemma INTEGER NOT NULL
  )
  ''';

  static const insertVerseWord =
      '''
  INSERT INTO $versesTable 
    ($versesColId, $versesColText, $versesColGrammar, $versesColLemma) 
    VALUES (?, ?, ?, ?);
  ''';

  // Hebrew/Greek text (words) table
  static const textTable = 'text';

  static const textColId = '_id';
  static const textColText = 'text';
  static const textColNoPunctuation = 'no_punctuation';
  static const textColNormalized = 'normalized'; // no diacritics

  static const createTextTable =
      '''
  CREATE TABLE IF NOT EXISTS $textTable (
    $textColId INTEGER PRIMARY KEY,
    $textColText TEXT NOT NULL,
    $textColNoPunctuation TEXT NOT NULL,
    $textColNormalized TEXT NOT NULL
  )
  ''';

  static const createTextNormalizedIndex =
      '''
  CREATE INDEX IF NOT EXISTS idx_normalized
  ON $textTable ($textColNormalized);
  ''';

  static const createTextNoPunctuationIndex =
      '''
  CREATE INDEX IF NOT EXISTS idx_no_punctuation
  ON $textTable ($textColNoPunctuation);
  ''';

  static const insertText =
      '''
  INSERT INTO $textTable
    ($textColId, $textColText, $textColNoPunctuation, $textColNormalized)
    VALUES (?, ?, ?, ?);
  ''';

  // Part of speech table
  static const grammarTable = 'grammar';

  static const grammarColId = '_id';
  static const grammarColGrammar = 'grammar';

  static const createGrammarTable =
      '''
  CREATE TABLE IF NOT EXISTS $grammarTable (
    $grammarColId INTEGER PRIMARY KEY,
    $grammarColGrammar TEXT NOT NULL
  )
  ''';

  static const insertGrammar =
      '''
  INSERT INTO $grammarTable
    ($grammarColId, $grammarColGrammar)
    VALUES (?, ?);
  ''';

  // Lemma table
  static const lemmaTable = 'lemma';

  static const lemmaColId = '_id';
  static const lemmaColLemma = 'lemma';

  static const createLemmaTable =
      '''
  CREATE TABLE IF NOT EXISTS $lemmaTable (
    $lemmaColId INTEGER PRIMARY KEY,
    $lemmaColLemma TEXT NOT NULL
  )
  ''';

  static const insertLemma =
      '''
  INSERT INTO $lemmaTable
    ($lemmaColId, $lemmaColLemma)
    VALUES (?, ?);
  ''';
}
