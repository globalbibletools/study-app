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
  late PreparedStatement _insertVerseWord;
  late PreparedStatement _insertText;
  late PreparedStatement _insertGrammar;
  late PreparedStatement _insertLemma;

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
    _database.execute(HebrewGreekSchema.createTextTable);
    _database.execute(HebrewGreekSchema.createGrammarTable);
    _database.execute(HebrewGreekSchema.createLemmaTable);
  }

  void _initPreparedStatements() {
    _insertVerseWord = _database.prepare(HebrewGreekSchema.insertVerseWord);
    _insertText = _database.prepare(HebrewGreekSchema.insertText);
    _insertGrammar = _database.prepare(HebrewGreekSchema.insertGrammar);
    _insertLemma = _database.prepare(HebrewGreekSchema.insertLemma);
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
    _database.execute(HebrewGreekSchema.createTextNormalizedIndex);
    _database.execute(HebrewGreekSchema.createTextNoPunctuationIndex);
  }

  Future<ForeignTableMaps> _populateForeignTables() async {
    final Map<String, int> textFrequencies = {};
    final Set<String> uniqueGrammar = {};
    final Set<String> uniqueLemma = {};

    for (final fileName in bookFileNames) {
      final file = File('../../data/hbo+grc/$fileName');
      final jsonData = await file.readAsString();
      print('Counting word frequencies in $fileName');
      final words = _extractWords(jsonData);
      for (final word in words) {
        final text = word.text.trim();
        textFrequencies.update(text, (count) => count + 1, ifAbsent: () => 1);
        uniqueGrammar.add(word.grammar.trim());
        uniqueLemma.add(word.lemma.trim());
      }
    }

    final sortedTextList = textFrequencies.keys.toList()
      ..sort((a, b) => textFrequencies[b]!.compareTo(textFrequencies[a]!));
    print('Total unique words: ${sortedTextList.length}');
    print(
      'Top 10 most frequent words: ${sortedTextList.take(10).map((w) => '"$w": ${textFrequencies[w]}').join(', ')}',
    );

    final textMap = _createTableWithNormalization(sortedTextList, _insertText);
    final grammarMap = _createTable(uniqueGrammar, _insertGrammar);
    final lemmaMap = _createTable(uniqueLemma, _insertLemma);

    return (textMap, grammarMap, lemmaMap);
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

  Map<String, int> _createTable(Set<String> unique, PreparedStatement stmt) {
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

  List<_HebrewGreekWord> _extractWords(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> chapters = data['chapters'];

    final List<_HebrewGreekWord> words = [];

    for (var chapter in chapters) {
      final verses = chapter['verses'] as List<dynamic>;
      for (var verse in verses) {
        final wordList = verse['words'] as List<dynamic>;
        for (var word in wordList) {
          words.add(_HebrewGreekWord.fromJson(word));
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
      final textForeignId = textMap[word.text];
      final grammarForeignId = grammarMap[word.grammar];
      final lemmaForeignId = lemmaMap[word.lemma];
      _insertVerseWord.execute([
        word.id,
        textForeignId,
        grammarForeignId,
        lemmaForeignId,
      ]);
    }
    _database.execute('COMMIT;');
  }

  void dispose() {
    _insertVerseWord.dispose();
    _insertText.dispose();
    _insertGrammar.dispose();
    _insertLemma.dispose();
    _database.dispose();
  }
}

class _HebrewGreekWord {
  /// ID is in the form of BBCCCVVVWW,
  /// where BB is the book number,
  /// CC is the chapter number,
  /// VVV is the verse number,
  /// and WW is the word number.
  final int id;
  final String text;
  final String grammar;
  final String lemma;

  _HebrewGreekWord({
    required this.id,
    required this.text,
    required this.grammar,
    required this.lemma,
  });

  factory _HebrewGreekWord.fromJson(Map<String, dynamic> json) {
    return _HebrewGreekWord(
      id: int.parse(json['id']),
      text: json['text']?.trim(),
      grammar: json['grammar']?.trim(),
      lemma: json['lemma']?.trim(),
    );
  }

  @override
  String toString() =>
      'HebrewGreekWord(id: $id, text: $text, grammar: $grammar, lemma: $lemma)';
}
