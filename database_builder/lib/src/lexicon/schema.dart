class LexiconSchema {
  /// Table to map Strong's code to the main IDs for the lemma
  /// 
  /// The idea is that you can look up a Strong's code and get back a list 
  /// of lemma IDs.
  static const strongsTable = "strongs";

  static const strongsColStrongs = "strongs_code";
  static const strongsColLemmaId = "lemma_id";

  static const createStrongsMappingTable = '''
  CREATE TABLE $strongsTable (
    $strongsColStrongs TEXT NOT NULL,
    $strongsColLemmaId INTEGER NOT NULL,
    PRIMARY KEY ($strongsColStrongs, $strongsColLemmaId)
  )
  ''';

  static const grammarTable = "grammar";
  static const grammarColId = "_id";
  static const grammarColText = "text";

  static const createGrammarTypesTable = '''
  CREATE TABLE $grammarTable (
    $grammarColId INTEGER PRIMARY KEY,
    $grammarColText TEXT NOT NULL UNIQUE
  )
  ''';

  static const meaningsTable = "meanings";
  static const meaningsColLexId = "lex_id";
  static const meaningsColLemmaId = "lemma_id";
  static const meaningsColGrammarId = "grammar_id";
  static const meaningsColLexEntryCode = "lex_entry_code";
  static const meaningsColDefinitionShort = "definition_short";
  static const meaningsColComments = "comments";
  static const meaningsColGlosses = "glosses";

  static const createMeaningsTable = '''
  CREATE TABLE $meaningsTable (
    $meaningsColLexId INTEGER PRIMARY KEY,
    $meaningsColLemmaId INTEGER NOT NULL,
    $meaningsColGrammarId INTEGER NOT NULL,
    $meaningsColLexEntryCode TEXT,
    $meaningsColDefinitionShort TEXT,
    $meaningsColComments TEXT,
    $meaningsColGlosses TEXT NOT NULL,
    FOREIGN KEY($meaningsColGrammarId) REFERENCES $grammarTable($grammarColId)
  )
  ''';
}