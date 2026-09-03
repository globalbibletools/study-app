import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../book_id.dart';
import 'normalization.dart';
import 'schema.dart';

typedef ForeignTableMaps = (
  Map<String, int>,
  Map<String, int>,
  Map<String, int>,
);

/// Old Testament source (books 1-39): hbo+grc JSON word data.
final otBookFileNames = bookFileNames.take(39).toList();

/// New Testament source (books 40-66): srgnt CSV word data.
const srCsvPath = 'lib/src/hebrew_greek/srgnt/sr.csv';

class HebrewGreekDatabase {
  final String _databaseName = "hebrew_greek.db";
  late Database _database;
  late PreparedStatement _insertVerse;
  late PreparedStatement _insertWord;
  late PreparedStatement _insertText;
  late PreparedStatement _insertGrammar;
  late PreparedStatement _insertStrongs;

  void init() {
    _database = sqlite3.open(_databaseName);
    _createTables();
    _initPreparedStatements();
  }

  void deleteDatabase() {
    final file = File(_databaseName);
    if (file.existsSync()) {
      log('Deleting database file: $_databaseName');
      file.deleteSync();
    }
  }

  void _createTables() {
    _database.execute(HebrewGreekSchema.createVersesTable);
    _database.execute(HebrewGreekSchema.createWordsTable);
    _database.execute(HebrewGreekSchema.createTextTable);
    _database.execute(HebrewGreekSchema.createGrammarTable);
    _database.execute(HebrewGreekSchema.createStrongsTable);

    _database
        .execute('PRAGMA user_version = ${HebrewGreekSchema.databaseVersion};');
  }

  void _initPreparedStatements() {
    _insertVerse = _database.prepare(HebrewGreekSchema.insertVerse);
    _insertWord = _database.prepare(HebrewGreekSchema.insertWord);
    _insertText = _database.prepare(HebrewGreekSchema.insertText);
    _insertGrammar = _database.prepare(HebrewGreekSchema.insertGrammar);
    _insertStrongs = _database.prepare(HebrewGreekSchema.insertStrongs);
  }

  Future<void> populateHebrewGreekTables() async {
    // OT words come from the hbo+grc JSON files; NT words come from
    // the srgnt sr.csv file, which is a more recent Greek text.
    final Map<String, List<_HebrewGreekWord>> otWords = {};
    for (final fileName in otBookFileNames) {
      final file = File('../../data/hbo+grc/$fileName');
      final jsonData = await file.readAsString();
      otWords[fileName] = _extractWords(jsonData);
    }
    final ntWords = await _readSrCsv();
    print('OT words: ${otWords.values.map((w) => w.length).reduce((a, b) => a + b)}');
    print('NT words: ${ntWords.length}');

    final (text, grammar, lemmas) = await _populateForeignTables(
      otWords,
      ntWords,
    );

    int wordCount = 0;
    for (final entry in otWords.entries) {
      print('Processing ${entry.key}');
      print('words: ${entry.value.length}');
      wordCount += entry.value.length;
      _addHebrewGreekWords(entry.value, text, grammar, lemmas);
    }
    print('Processing $srCsvPath');
    print('words: ${ntWords.length}');
    wordCount += ntWords.length;
    _addHebrewGreekWords(ntWords, text, grammar, lemmas);
    print('Total Hebrew/Greek words: $wordCount');

    // add indexes
    _database.execute(HebrewGreekSchema.createWordsVerseIdIndex);
    _database.execute(HebrewGreekSchema.createTextNormalizedIndex);
    _database.execute(HebrewGreekSchema.createTextNoPunctuationIndex);
  }

  Future<ForeignTableMaps> _populateForeignTables(
    Map<String, List<_HebrewGreekWord>> otWords,
    List<_HebrewGreekWord> ntWords,
  ) async {
    final Map<String, int> textFrequencies = {};
    final Set<String> uniqueGrammar = {};
    final Set<String> uniqueStrongs = {};

    void countWords(Iterable<_HebrewGreekWord> words) {
      for (final word in words) {
        final text = word.text.trim();
        textFrequencies.update(text, (count) => count + 1, ifAbsent: () => 1);
        uniqueGrammar.add(word.grammar.trim());
        uniqueStrongs.add(word.lemma.trim());
      }
    }

    for (final fileName in otBookFileNames) {
      print('Counting word frequencies in $fileName');
      countWords(otWords[fileName]!);
    }
    print('Counting word frequencies in $srCsvPath');
    countWords(ntWords);

    final sortedTextList = textFrequencies.keys.toList()
      ..sort((a, b) => textFrequencies[b]!.compareTo(textFrequencies[a]!));
    print('Total unique words: ${sortedTextList.length}');
    print(
      'Top 10 most frequent words: ${sortedTextList.take(10).map((w) => '"$w": ${textFrequencies[w]}').join(', ')}',
    );

    final textMap = _createTableWithNormalization(sortedTextList, _insertText);
    final grammarMap = _createGrammarTable(uniqueGrammar, _insertGrammar);
    final strongsMap = await _createStrongsTable(uniqueStrongs, _insertStrongs);

    return (textMap, grammarMap, strongsMap);
  }

  Map<String, int> _createTableWithNormalization(
    List<String> sortedUnique,
    PreparedStatement stmt,
  ) {
    final Map<String, int> map = {};
    _database.execute('BEGIN TRANSACTION;');
    for (int i = 0; i < sortedUnique.length; i++) {
      final text = sortedUnique[i];
      final noPunctuation = removePunctuation(text);
      final normalized = normalizeHebrewGreek(text);
      final id = i + 1;
      map[text] = id;
      stmt.execute([id, text, noPunctuation, normalized]);
    }
    _database.execute('COMMIT;');
    return map;
  }

  Map<String, int> _createGrammarTable(
    Set<String> unique,
    PreparedStatement stmt,
  ) {
    final list = unique.toList()..sort();
    final Map<String, int> map = {};
    _database.execute('BEGIN TRANSACTION;');
    for (int i = 0; i < list.length; i++) {
      final text = list[i];
      final id = i + 1;
      map[text] = id;
      stmt.execute([id, text]);
    }
    _database.execute('COMMIT;');
    return map;
  }

  Future<Map<String, int>> _createStrongsTable(
    Set<String> unique,
    PreparedStatement stmt,
  ) async {
    final list = unique.toList()..sort();

    final Map<String, String> strongsMap = {};
    await _populateStrongsMap(
      'lib/src/hebrew_greek/strongs_data/strongs-greek.txt',
      'G',
      strongsMap,
    );
    await _populateStrongsMap(
      'lib/src/hebrew_greek/strongs_data/strongs-hebrew.txt',
      'H',
      strongsMap,
    );

    final Map<String, int> output = {};
    _database.execute('BEGIN TRANSACTION;');
    for (int i = 0; i < list.length; i++) {
      final text = list[i];
      final id = i + 1;
      var root = strongsMap[text.substring(0, 5)];
      if (root == null || root == 'NONE') {
        print('No Strong\'s root found: text: $text, id: $id');
        root = null;
      }
      output[text] = id;
      stmt.execute([id, text, root]);
    }
    _database.execute('COMMIT;');
    return output;
  }

  Future<void> _populateStrongsMap(
    String filePath,
    String prefix,
    Map<String, String> map,
  ) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    for (var line in lines) {
      final parts = line.split('|');
      final numberStr = parts[0].trim();
      final word = parts[1].trim();
      final formattedNumber = numberStr.padLeft(4, '0');
      final key = '$prefix$formattedNumber';
      map[key] = word;
    }
  }

  List<_HebrewGreekWord> _extractWords(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final int bookId = data['id'];
    final List<dynamic> chapters = data['chapters'];

    final List<_HebrewGreekWord> words = [];

    for (var chapter in chapters) {
      final int chapterId = chapter['id'];
      final verses = chapter['verses'] as List<dynamic>;
      for (var verse in verses) {
        final String verseId = verse['id'].toString();
        final int verseIdInt = int.parse(verseId);
        final int verseNumber = verseIdInt % 1000;
        final wordList = verse['words'] as List<dynamic>;
        for (var word in wordList) {
          words.add(_HebrewGreekWord.fromJson(
            word,
            bookId: bookId,
            chapterId: chapterId,
            verseNumber: verseNumber,
            verseId: verseId,
          ));
        }
      }
    }

    return words;
  }

  /// Reads the New Testament word data from the srgnt sr.csv file.
  ///
  /// The CSV has a header row and columns:
  /// id,text,grammar,lemma_id,gloss
  Future<List<_HebrewGreekWord>> _readSrCsv() async {
    final file = File(srCsvPath);
    final content = await file.readAsString();
    final rows = _parseCsv(content);

    final List<_HebrewGreekWord> words = [];
    // Skip the header row.
    for (final row in rows.skip(1)) {
      if (row.length < 4) {
        throw FormatException('Malformed sr.csv row: $row');
      }
      words.add(_HebrewGreekWord.fromSrCsvRow(row));
    }
    return words;
  }

  /// Minimal RFC 4180 CSV parser: handles quoted fields, escaped quotes
  /// (""), commas inside quotes, and \r\n line endings.
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < content.length; i++) {
      final c = content[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n') {
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else if (c != '\r') {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  void _addHebrewGreekWords(
    List<_HebrewGreekWord> words,
    Map<String, int> textMap,
    Map<String, int> grammarMap,
    Map<String, int> lemmaMap,
  ) {
    _database.execute('BEGIN TRANSACTION;');
    for (var word in words) {
      // Insert the verse row (deduped on verse_id via INSERT OR IGNORE).
      _insertVerse.execute([
        word.verseId,
        word.bookId,
        word.chapterId,
        word.verseNumber,
      ]);

      final textForeignId = textMap[word.text];
      final grammarForeignId = grammarMap[word.grammar];
      final lemmaForeignId = lemmaMap[word.lemma];
      _insertWord.execute([
        word.sourceId,
        word.verseId,
        textForeignId,
        grammarForeignId,
        lemmaForeignId,
      ]);
    }
    _database.execute('COMMIT;');
  }

  void dispose() {
    _insertVerse.close();
    _insertWord.close();
    _insertText.close();
    _insertGrammar.close();
    _insertStrongs.close();
    _database.close();
  }
}

class _HebrewGreekWord {
  /// The source word id as a string (BBCCCVVVWW, e.g. "0100100101").
  /// This is the opaque primary key shared with the gloss DBs.
  ///
  /// New Testament ids from the srgnt data may carry an optional -NN
  /// suffix (e.g. "4000101309-01") marking a word added after ids were
  /// assigned; the suffix preserves word order.
  final String sourceId;

  /// The verse id (BBCCCVVV) this word belongs to.
  final String verseId;
  final int bookId;
  final int chapterId;
  final int verseNumber;

  final String text;
  final String grammar;
  final String lemma;

  _HebrewGreekWord({
    required this.sourceId,
    required this.verseId,
    required this.bookId,
    required this.chapterId,
    required this.verseNumber,
    required this.text,
    required this.grammar,
    required this.lemma,
  });

  factory _HebrewGreekWord.fromJson(
    Map<String, dynamic> json, {
    required int bookId,
    required int chapterId,
    required int verseNumber,
    required String verseId,
  }) {
    final sourceId = json['id'].toString();
    final expectedVersePrefix = verseId;
    if (!sourceId.startsWith(expectedVersePrefix)) {
      throw StateError(
        "Source word id '$sourceId' does not belong to verse "
        "'$expectedVersePrefix' (book $bookId, chapter $chapterId, "
        "verse $verseNumber).",
      );
    }
    return _HebrewGreekWord(
      sourceId: sourceId,
      verseId: verseId,
      bookId: bookId,
      chapterId: chapterId,
      verseNumber: verseNumber,
      text: json['text']?.trim(),
      grammar: json['grammar']?.trim(),
      lemma: json['lemma']?.trim(),
    );
  }

  @override
  String toString() =>
      'HebrewGreekWord(sourceId: $sourceId, verseId: $verseId, text: $text, grammar: $grammar, lemma: $lemma)';

  /// Builds a word from an srgnt sr.csv row.
  ///
  /// The id column is in the form BBCCCVVVWW(-NN): BB is the book
  /// number, CCC the chapter, VVV the verse, WW the word number, and the
  /// optional zero-padded -NN suffix marks a word added after ids were
  /// assigned (preserving word order). The book, chapter, and verse are
  /// parsed from the id prefix, since the CSV carries no separate verse
  /// metadata.
  factory _HebrewGreekWord.fromSrCsvRow(List<String> row) {
    final sourceId = row[0].trim();

    // The numeric prefix before any -NN suffix encodes BBCCCVVVWW.
    final dashIndex = sourceId.indexOf('-');
    final baseId = dashIndex == -1 ? sourceId : sourceId.substring(0, dashIndex);
    if (baseId.length != 10 || int.tryParse(baseId) == null) {
      throw FormatException(
        'Malformed sr.csv word id: "$sourceId" in row: $row',
      );
    }

    final verseId = baseId.substring(0, 8);
    final bookId = int.parse(baseId.substring(0, 2));
    final chapterId = int.parse(baseId.substring(2, 5));
    final verseNumber = int.parse(baseId.substring(5, 8));

    if (!sourceId.startsWith(verseId)) {
      throw FormatException(
        'Malformed sr.csv word id: "$sourceId" does not belong to verse '
        '"$verseId".',
      );
    }

    return _HebrewGreekWord(
      sourceId: sourceId,
      verseId: verseId,
      bookId: bookId,
      chapterId: chapterId,
      verseNumber: verseNumber,
      text: row[1].trim(),
      grammar: row[2].trim(),
      lemma: row[3].trim(),
    );
  }
}
