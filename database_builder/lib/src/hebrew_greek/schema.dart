class HebrewGreekSchema {
  // Verses table
  //
  // One row per unique verse reference. The word id is now opaque and no
  // longer encodes book/chapter/verse, so the reference is stored here and
  // joined through `words.verse_id`.
  static const versesTable = 'verses';

  static const versesColVerseId = 'verse_id'; // BBCCCVVV, e.g. "40001001"
  static const versesColBook = 'book';
  static const versesColChapter = 'chapter';
  static const versesColVerse = 'verse';

  static const createVersesTable =
      '''
  CREATE TABLE IF NOT EXISTS $versesTable (
    $versesColVerseId TEXT PRIMARY KEY,
    $versesColBook INTEGER NOT NULL,
    $versesColChapter INTEGER NOT NULL,
    $versesColVerse INTEGER NOT NULL
  )
  ''';

  static const insertVerse =
      '''
  INSERT OR IGNORE INTO $versesTable
    ($versesColVerseId, $versesColBook, $versesColChapter, $versesColVerse)
    VALUES (?, ?, ?, ?);
  ''';

  // Words table (formerly the `verses` table)
  //
  // Contains one row per word, in biblical order. All of the words are
  // encoded as integers that reference other tables. This saves space
  // because many words are repeated and integers take up less space than
  // strings. The `verse_id` column links each word to its verse reference.
  static const wordsTable = 'words';

  static const wordsColId = '_id';
  static const wordsColVerseId = 'verse_id'; // foreign key -> verses.verse_id
  static const wordsColText = 'text'; // foreign key to text table
  static const wordsColGrammar = 'grammar'; // foreign key to grammar table
  static const wordsColStrongs = 'strongs'; // foreign key to strongs table

  static const createWordsTable =
      '''
  CREATE TABLE IF NOT EXISTS $wordsTable (
    $wordsColId INTEGER PRIMARY KEY,
    $wordsColVerseId TEXT NOT NULL,
    $wordsColText INTEGER NOT NULL,
    $wordsColGrammar INTEGER NOT NULL,
    $wordsColStrongs INTEGER NOT NULL,
    FOREIGN KEY ($wordsColVerseId) REFERENCES $versesTable($versesColVerseId)
  )
  ''';

  static const createWordsVerseIdIndex =
      '''
  CREATE INDEX IF NOT EXISTS idx_words_verse_id
  ON $wordsTable ($wordsColVerseId);
  ''';

  static const insertWord =
      '''
  INSERT INTO $wordsTable
    ($wordsColId, $wordsColVerseId, $wordsColText, $wordsColGrammar, $wordsColStrongs)
    VALUES (?, ?, ?, ?, ?);
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

  // Strongs table
  static const strongsTable = 'strongs';

  static const strongsColId = '_id';
  static const strongsColCode = 'code';
  static const strongsColRoot = 'root';

  static const createStrongsTable =
      '''
  CREATE TABLE IF NOT EXISTS $strongsTable (
    $strongsColId INTEGER PRIMARY KEY,
    $strongsColCode TEXT NOT NULL,
    $strongsColRoot TEXT
  )
  ''';

  static const insertStrongs =
      '''
  INSERT INTO $strongsTable
    ($strongsColId, $strongsColCode, $strongsColRoot)
    VALUES (?, ?, ?);
  ''';
}
