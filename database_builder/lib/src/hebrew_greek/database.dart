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
    final (text, grammar, lemmas) = await _populateForeignTables();

    int wordCount = 0;
    for (final fileName in bookFileNames) {
      final file = File('../../data/hbo+grc/$fileName');
      final jsonData = await file.readAsString();
      print('Processing $fileName');
      final words = _extractWords(jsonData);
      print('words: ${words.length}');
      wordCount += words.length;
      _addHebrewGreekWords(words, text, grammar, lemmas);
    }
    print('Total Hebrew/Greek words: $wordCount');

    // add indexes
    _database.execute(HebrewGreekSchema.createWordsVerseIdIndex);
    _database.execute(HebrewGreekSchema.createTextNormalizedIndex);
    _database.execute(HebrewGreekSchema.createTextNoPunctuationIndex);
  }

  Future<ForeignTableMaps> _populateForeignTables() async {
    final Map<String, int> textFrequencies = {};
    final Set<String> uniqueGrammar = {};
    final Set<String> uniqueStrongs = {};

    for (final fileName in bookFileNames) {
      final file = File('../../data/hbo+grc/$fileName');
      final jsonData = await file.readAsString();
      print('Counting word frequencies in $fileName');
      final words = _extractWords(jsonData);
      for (final word in words) {
        final text = word.text.trim();
        textFrequencies.update(text, (count) => count + 1, ifAbsent: () => 1);
        uniqueGrammar.add(word.grammar.trim());
        uniqueStrongs.add(word.lemma.trim());
      }
    }

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
}
