import 'dart:developer';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

class DatabaseHelper {
  final String _databaseName = "database.db";
  late Database _database;

  void init() {
    _database = sqlite3.open(_databaseName);
    _createBsbTable();
    _createOriginalLanguageTable();
    _createEnglishTable();
    _createPartOfSpeechTable();
    _createInterlinearTable();
  }

  void deleteDatabase() {
    final file = File(_databaseName);
    if (file.existsSync()) {
      print('Deleting database file: $_databaseName');
      file.deleteSync();
    }
  }

  void _createBsbTable() {
    _database.execute(Schema.createBsbTable);
  }

  void _createOriginalLanguageTable() {
    _database.execute(Schema.createOriginalLanguageTable);
  }

  void _createEnglishTable() {
    _database.execute(Schema.createEnglishTable);
  }

  void _createPartOfSpeechTable() {
    _database.execute(Schema.createPartOfSpeechTable);
  }

  void _createInterlinearTable() {
    _database.execute(Schema.createInterlinearTable);
  }

  Future<void> insertBsbLine({
    required int bookId,
    required int chapter,
    required int verse,
    required String text,
    required int type,
    required int? format,
    required String? footnote,
  }) async {
    if (text.isEmpty) {
      throw Exception('Empty text for $bookId, $chapter, $verse');
    }
    _database.execute('''
      INSERT INTO ${Schema.bibleTextTable} (
        ${Schema.colBookId},
        ${Schema.colChapter},
        ${Schema.colVerse},
        ${Schema.colText},
        ${Schema.colType},
        ${Schema.colFormat},
        ${Schema.colFootnote}
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [bookId, chapter, verse, text, type, format, footnote]);
  }

  int insertOriginalLanguage({
    required String word,
  }) {
    _database.execute('''
      INSERT INTO ${Schema.originalLanguageTable} (
        ${Schema.olColWord}
      ) VALUES (?)
      ''', [word]);
    return _database.lastInsertRowId;
  }

  int insertEnglish({
    required String word,
  }) {
    _database.execute('''
      INSERT INTO ${Schema.englishTable} (
        ${Schema.engColWord}
      ) VALUES (?)
      ''', [word]);
    return _database.lastInsertRowId;
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

  void insertInterlinearVerse(
    List<InterlinearWord> words,
    int bookId,
    int chapter,
    int verse,
  ) {
    if (bookId == -1 || chapter == -1 || verse == -1) {
      log('Invalid bookId, chapter, or verse: $bookId, $chapter, $verse');
    }
    for (var word in words) {
      _database.execute('''
        INSERT INTO ${Schema.interlinearTable} (
          ${Schema.ilColBookId},
          ${Schema.ilColChapter},
          ${Schema.ilColVerse},
          ${Schema.ilColLanguage},
          ${Schema.ilColOriginal},
          ${Schema.ilColPartOfSpeech},
          ${Schema.ilColStrongsNumber},
          ${Schema.ilColEnglish},
          ${Schema.ilColPunctuation}
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
        bookId,
        chapter,
        verse,
        word.language,
        word.original,
        word.partOfSpeech,
        word.strongsNumber,
        word.english,
        word.punctuation,
      ]);
    }
  }
}

class InterlinearWord {
  InterlinearWord({
    required this.language,
    required this.original,
    required this.partOfSpeech,
    required this.strongsNumber,
    required this.english,
    required this.punctuation,
  });
  final int language;
  final int original;
  final int partOfSpeech;
  final int strongsNumber;
  final int english;
  final String? punctuation;
}
