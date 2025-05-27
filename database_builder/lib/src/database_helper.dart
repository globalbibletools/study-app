import 'dart:developer';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

class DatabaseHelper {
  final String _databaseName = "database.db";
  late Database _database;
  late PreparedStatement _insertHebrewGreekWord;
  late PreparedStatement _insertGloss;

  void init() {
    _database = sqlite3.open(_databaseName);
    _createHebrewGreekTable();
    _createEnglishTable();
    _createPartOfSpeechTable();
    _initPreparedStatements();
  }

  void deleteDatabase() {
    final file = File(_databaseName);
    if (file.existsSync()) {
      log('Deleting database file: $_databaseName');
      file.deleteSync();
    }
  }

  void _createHebrewGreekTable() {
    _database.execute(Schema.createHebrewGreekTable);
  }

  void _createEnglishTable() {
    _database.execute(Schema.createEnglishTable);
  }

  void _createPartOfSpeechTable() {
    _database.execute(Schema.createPartOfSpeechTable);
  }

  void _initPreparedStatements() {
    _insertHebrewGreekWord = _database.prepare(Schema.insertHebrewGreekWord);
    _insertGloss = _database.prepare(Schema.insertGloss);
  }

  int insertPartOfSpeech({
    required String name,
  }) {
    _database.execute('''
      INSERT INTO ${Schema.partOfSpeechTable} (
        ${Schema.posColName}
      ) VALUES (?)
      ''', [name]);
    return _database.lastInsertRowId;
  }

  void addHebrewGreekWords(List<HebrewGreekWord> words) {
    _database.execute('BEGIN TRANSACTION;');
    for (var word in words) {
      _insertHebrewGreekWord.execute([word.id, word.text, word.grammar, word.lemma]);
    }
    _database.execute('COMMIT;');
  }

  void addGlosses(List<Gloss> glosses) {
    _database.execute('BEGIN TRANSACTION;');
    for (var gloss in glosses) {
      _insertGloss.execute([gloss.id, gloss.gloss]);
    }
    _database.execute('COMMIT;');
  }

  void dispose() {
    _insertHebrewGreekWord.dispose();
    _insertGloss.dispose();
    _database.dispose();
  }
}

class HebrewGreekWord {
  final String id;
  final String text;
  final String grammar;
  final String lemma;

  HebrewGreekWord({
    required this.id,
    required this.text,
    required this.grammar,
    required this.lemma,
  });

  factory HebrewGreekWord.fromJson(Map<String, dynamic> json) {
    return HebrewGreekWord(
      id: json['id'],
      text: json['text'],
      grammar: json['grammar'],
      lemma: json['lemma'],
    );
  }

  @override
  String toString() => 'Word(id: $id, text: $text, grammar: $grammar, lemma: $lemma)';
}

class Gloss {
  final String id;
  final String? gloss;

  Gloss({
    required this.id,
    required this.gloss,
  });

  factory Gloss.fromJson(Map<String, dynamic> json) {
    return Gloss(
      id: json['id'],
      gloss: json['gloss'],
    );
  }

  @override
  String toString() => 'Word(id: $id, gloss: $gloss)';
}
