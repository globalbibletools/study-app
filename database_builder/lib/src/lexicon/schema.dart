class LexiconSchema {
  /// Table to map Strong's code to the main IDs for the lemma
  ///
  /// The idea is that you can look up a Strong's code and get back a list
  /// of lemma IDs.
  static const strongsTable = "strongs";

  static const strongsColStrongs = "strongs_code";

  static const lemmaIdOffset = 1000000000;

  /// This should be stored by dividing the original lemma id from the JSON
  /// by [lemmaIdOffset] to remove the trailing 0s. [createMeaningsLemmaIdIndex]
  /// below assumes such an approach.
  static const strongsColLemmaId = "lemma_id";

  static const createStrongsTable =
      '''
  CREATE TABLE $strongsTable (
    $strongsColStrongs TEXT NOT NULL,
    $strongsColLemmaId INTEGER NOT NULL,
    PRIMARY KEY ($strongsColStrongs, $strongsColLemmaId)
  )
  ''';

  /// Table of Parts of Speech for a given lemma base form
  static const grammarTable = "grammar";
  static const grammarColId = "_id";
  static const grammarColText = "text";

  static const createGrammarTypesTable =
      '''
  CREATE TABLE $grammarTable (
    $grammarColId INTEGER PRIMARY KEY,
    $grammarColText TEXT NOT NULL UNIQUE
  )
  ''';

  static const meaningsTable = "meanings";
  static const meaningsColLexId = "lex_id";
  static const meaningsColGrammarId = "grammar_id";
  static const meaningsColLemma = 'Lemma';
  static const meaningsColLexEntryCode = "lex_entry_code";
  static const meaningsColDefinitionShort = "definition_short";
  static const meaningsColComments = "comments";
  static const meaningsColGlosses = "glosses";

  static const createMeaningsTable =
      '''
  CREATE TABLE $meaningsTable (
    $meaningsColLexId INTEGER PRIMARY KEY,
    $meaningsColGrammarId INTEGER,
    $meaningsColLemma TEXT NOT NULL,
    $meaningsColLexEntryCode TEXT,
    $meaningsColDefinitionShort TEXT,
    $meaningsColComments TEXT,
    $meaningsColGlosses TEXT NOT NULL,
    FOREIGN KEY($meaningsColGrammarId) REFERENCES $grammarTable($grammarColId)
  )
  ''';

  static const createStrongsCodeIndex =
      'CREATE INDEX idx_strongs_code ON $strongsTable ($strongsColStrongs)';

  /// Assumes that lemma ID in grammar table start with 1, not [lemmaIdOffset].
  static const createMeaningsLemmaIdIndex =
      'CREATE INDEX idx_meanings_derived_lemma_id ON $meaningsTable ($meaningsColLexId / $lemmaIdOffset)';

  // --- Query Strings ---

  /// Query to get all meanings for a single Strong's number.
  ///
  /// This query joins the `strongs` and `meanings` tables by deriving the
  /// lemma_id from the lex_id. The '?' should be replaced with the
  /// specific Strong's code argument.
  static const getMeaningsForStrongsQuery =
      '''
    SELECT
      m.$meaningsColLexId,
      m.$meaningsColLemma,
      m.$meaningsColLexEntryCode,
      m.$meaningsColDefinitionShort,
      m.$meaningsColComments,
      m.$meaningsColGlosses,
      g.$grammarColText
    FROM $meaningsTable AS m
    JOIN $strongsTable AS s
      ON (m.$meaningsColLexId / $lemmaIdOffset) = s.$strongsColLemmaId
    LEFT JOIN $grammarTable AS g
      ON m.$meaningsColGrammarId = g.$grammarColId
    WHERE s.$strongsColStrongs = ?
  ''';
}
