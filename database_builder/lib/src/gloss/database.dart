import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../book_id.dart';
import 'schema.dart';

class GlossDatabase {
  GlossDatabase({required this.languageIsoCode});

  /// The name of the database file. Use the ISO code for the language.
  final String languageIsoCode;

  late Database _database;
  late PreparedStatement _insertVerseGloss;
  late PreparedStatement _insertText;

  void init() {
    _database = sqlite3.open('$languageIsoCode.db');
    _createTables();
    _initPreparedStatements();
  }

  void deleteDatabase() {
    final filename = '$languageIsoCode.db';
    final file = File(filename);
    if (file.existsSync()) {
      log('Deleting database file: $filename');
      file.deleteSync();
    }
  }

  void _createTables() {
    _database.execute(GlossSchema.createVersesTable);
    _database.execute(GlossSchema.createTextTable);
  }

  void _initPreparedStatements() {
    _insertVerseGloss = _database.prepare(GlossSchema.insertVerseGloss);
    _insertText = _database.prepare(GlossSchema.insertText);
  }

  Future<void> populateGlossTable() async {
    final text = await _createForeignTable();

    int wordCount = 0;
    for (final fileName in bookFileNames) {
      final file = File('../../data/$languageIsoCode/$fileName');
      final jsonData = await file.readAsString();
      print('Processing $fileName');
      final words = _extractWords(jsonData);
      print('words: ${words.length}');
      wordCount += words.length;
      _addGlossWords(words, text);
    }
    print('Total Hebrew/Greek words: $wordCount');
  }

  Future<Map<String, int>> _createForeignTable() async {
    final Set<String> uniqueText = {};

    for (final fileName in bookFileNames) {
      final file = File('../../data/$languageIsoCode/$fileName');
      final jsonData = await file.readAsString();
      print('Finding unique words in $fileName');
      final words = _extractWords(jsonData);
      for (final word in words) {
        if (word.gloss == null) continue;
        uniqueText.add(word.gloss!);
      }
    }
    return _createTable(uniqueText, _insertText);
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

  List<Gloss> _extractWords(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> chapters = data['chapters'];

    final List<Gloss> words = [];

    for (var chapter in chapters) {
      final List<dynamic> verses = chapter['verses'];
      for (var verse in verses) {
        final List<dynamic> wordList = verse['words'];
        for (var word in wordList) {
          words.add(Gloss.fromJson(word));
        }
      }
    }

    return words;
  }

  void _addGlossWords(List<Gloss> words, Map<String, int> textMap) {
    _database.execute('BEGIN TRANSACTION;');
    for (var word in words) {
      final textForeignId = textMap[word.gloss];
      _insertVerseGloss.execute([word.id, textForeignId]);
    }
    _database.execute('COMMIT;');
  }

  void dispose() {
    _insertVerseGloss.dispose();
    _insertText.dispose();
    _database.dispose();
  }
}

class Gloss {
  final int id;
  final String? gloss;

  Gloss({required this.id, required this.gloss});

  factory Gloss.fromJson(Map<String, dynamic> json) {
    final id = int.parse(json['id']);
    var gloss = json['gloss']?.trim();
    return Gloss(id: id, gloss: gloss);
  }

  @override
  String toString() => 'Word(id: $id, gloss: $gloss)';
}
