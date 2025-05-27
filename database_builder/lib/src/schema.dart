class Schema {
  // Part of speech table
  static const String partOfSpeechTable = "pos";

  static const String posColId = '_id';
  static const String posColName = 'name';

  static const String createPartOfSpeechTable = '''
  CREATE TABLE IF NOT EXISTS $partOfSpeechTable (
    $posColId INTEGER PRIMARY KEY AUTOINCREMENT,
    $posColName TEXT NOT NULL
  )
  ''';

  // Hebrew Greek table
  static const String hebrewGreekTable = "hebrew_greek";

  static const String hgColId = '_id';
  static const String hgColText = 'text';
  static const String hgColGrammar = 'grammar';
  static const String hgColLemma = 'lemma';

  static const String createHebrewGreekTable = '''
  CREATE TABLE IF NOT EXISTS $hebrewGreekTable (
    $hgColId INTEGER PRIMARY KEY,
    $hgColText TEXT NOT NULL,
    $hgColGrammar TEXT NOT NULL,
    $hgColLemma TEXT NOT NULL
  )
  ''';

  static const String insertHebrewGreekWord = '''
  INSERT INTO $hebrewGreekTable 
    ($hgColId, $hgColText, $hgColGrammar, $hgColLemma) 
    VALUES (?, ?, ?, ?);
  ''';

  // English language table
  static const String englishTable = "english";

  static const String engColId = '_id';
  static const String engColGloss = 'gloss';

  static const String createEnglishTable = '''
  CREATE TABLE IF NOT EXISTS $englishTable (
    $engColId INTEGER PRIMARY KEY,
    $engColGloss TEXT
  )
  ''';

  static const String insertGloss = '''
  INSERT INTO $englishTable 
    ($engColId, $engColGloss) 
    VALUES (?, ?);
  ''';
}
