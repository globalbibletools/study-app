class LexiconSchema {
  static const lemmasTable = "lemmas";
  static const lemmasColMainId = "main_id";
  static const lemmasColLemmaText = "lemma_text";

  static const createLemmasTable = '''
  CREATE TABLE $lemmasTable (
    $lemmasColMainId INTEGER PRIMARY KEY,
    $lemmasColLemmaText TEXT NOT NULL
  )
  ''';

  static const strongsMappingTable = "strongs_mapping";
  static const strongsMappingColStrongCode = "strong_code";
  static const strongsMappingColLemmaId = "lemma_id";

  static const createStrongsMappingTable = '''
  CREATE TABLE $strongsMappingTable (
    $strongsMappingColStrongCode TEXT NOT NULL,
    $strongsMappingColLemmaId INTEGER NOT NULL,
    PRIMARY KEY ($strongsMappingColStrongCode, $strongsMappingColLemmaId)
  )
  ''';

  static const grammarTypesTable = "grammar_types";
  static const grammarTypesColId = "id";
  static const grammarTypesColGrammarText = "grammar_text";

  static const createGrammarTypesTable = '''
  CREATE TABLE $grammarTypesTable (
    $grammarTypesColId INTEGER PRIMARY KEY,
    $grammarTypesColGrammarText TEXT NOT NULL UNIQUE
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
    FOREIGN KEY($meaningsColLemmaId) REFERENCES $lemmasTable($lemmasColMainId),
    FOREIGN KEY($meaningsColGrammarId) REFERENCES $grammarTypesTable($grammarTypesColId)
  )
  ''';
}