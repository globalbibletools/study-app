import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/common/word.dart';

class HebrewGreekDatabase {
  static const _databaseName = 'hebrew_greek.db';
  static const _databaseVersion = 5;
  late Database _database;

  Future<void> init() async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, _databaseName);
    var exists = await databaseExists(path);

    if (!exists) {
      log('Creating new copy of $_databaseName from assets');
      await _copyDatabaseFromAssets(path);
    } else {
      // Check if database needs update
      var currentVersion = await _getDatabaseVersion(path);
      if (currentVersion != _databaseVersion) {
        log(
          'Updating Hebrew/Greek database from version $currentVersion to $_databaseVersion',
        );
        await deleteDatabase(path);
        await _copyDatabaseFromAssets(path);
      } else {
        log("Opening existing $_databaseName database");
      }
    }
    _database = await openDatabase(path, version: _databaseVersion);
  }

  Future<int> _getDatabaseVersion(String path) async {
    var db = await openDatabase(path);
    var version = await db.getVersion();
    await db.close();
    return version;
  }

  Future<void> _copyDatabaseFromAssets(String path) async {
    await Directory(dirname(path)).create(recursive: true);
    final data = await rootBundle.load(join('assets/databases', _databaseName));
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<List<HebrewGreekWord>> getChapter(int bookId, int chapter) async {
    const int bookMultiplier = 100000000;
    const int chapterMultiplier = 100000;
    final int lowerBound =
        bookId * bookMultiplier + chapter * chapterMultiplier;
    final int upperBound =
        bookId * bookMultiplier + (chapter + 1) * chapterMultiplier;

    final List<Map<String, dynamic>> words = await _database.rawQuery(
      'SELECT v.${HebrewGreekSchema.versesColId}, '
      't.${HebrewGreekSchema.textColText} '
      'FROM ${HebrewGreekSchema.versesTable} v '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON v.${HebrewGreekSchema.versesColText} = t.${HebrewGreekSchema.textColId} '
      'WHERE v.${HebrewGreekSchema.versesColId} >= ? AND v.${HebrewGreekSchema.versesColId} < ? '
      'ORDER BY v.${HebrewGreekSchema.versesColId} ASC',
      [lowerBound, upperBound],
    );

    return words
        .map(
          (word) => HebrewGreekWord(
            id: word[HebrewGreekSchema.versesColId],
            text: word[HebrewGreekSchema.textColText],
          ),
        )
        .toList();
  }

  Future<String?> getWordForId(int wordId) async {
    final List<Map<String, dynamic>> words = await _database.rawQuery(
      'SELECT v.${HebrewGreekSchema.versesColId}, '
      't.${HebrewGreekSchema.textColText} '
      'FROM ${HebrewGreekSchema.versesTable} v '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON v.${HebrewGreekSchema.versesColText} = t.${HebrewGreekSchema.textColId} '
      'WHERE v.${HebrewGreekSchema.versesColId} == ?',
      [wordId],
    );
    return words.first[HebrewGreekSchema.textColText];
  }

  Future<(String, String)?> getStrongsAndGrammar(int wordId) async {
    final List<Map<String, dynamic>> result = await _database.rawQuery(
      '''SELECT l.${HebrewGreekSchema.lemmaColLemma}, g.${HebrewGreekSchema.grammarColGrammar}
      FROM ${HebrewGreekSchema.versesTable} v
      JOIN ${HebrewGreekSchema.lemmaTable} l 
      ON v.${HebrewGreekSchema.versesColLemma} = l.${HebrewGreekSchema.lemmaColId}
      JOIN ${HebrewGreekSchema.grammarTable} g 
      ON v.${HebrewGreekSchema.versesColGrammar} = g.${HebrewGreekSchema.grammarColId}
      WHERE v.${HebrewGreekSchema.versesColId} = ?''',
      [wordId],
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    final lemma = row[HebrewGreekSchema.lemmaColLemma] as String;
    final grammar = row[HebrewGreekSchema.grammarColGrammar] as String;
    return (lemma, grammar);
  }

  Future<List<int>> allWordsForStrongsCode(String strongsCode) async {
    final List<Map<String, dynamic>> maps = await _database.rawQuery(
      '''SELECT v.${HebrewGreekSchema.versesColId}
      FROM ${HebrewGreekSchema.versesTable} AS v
      INNER JOIN ${HebrewGreekSchema.lemmaTable} AS l 
      ON v.${HebrewGreekSchema.versesColLemma} = l.${HebrewGreekSchema.lemmaColId}
      WHERE l.${HebrewGreekSchema.lemmaColLemma} = ?
      ''',
      [strongsCode],
    );

    if (maps.isNotEmpty) {
      return maps
          .map((map) => map[HebrewGreekSchema.versesColId] as int)
          .toList();
    }

    return [];
  }

  Future<List<HebrewGreekWord>> wordsForVerse(
    Reference reference, {
    bool includeStrongs = false,
  }) async {
    const int bookMultiplier = 100000000;
    const int chapterMultiplier = 100000;
    const int verseMultiplier = 100;
    final int lowerBound =
        reference.bookId * bookMultiplier +
        reference.chapter * chapterMultiplier +
        reference.verse * verseMultiplier;
    final int upperBound =
        reference.bookId * bookMultiplier +
        reference.chapter * chapterMultiplier +
        (reference.verse + 1) * verseMultiplier;

    final sql = StringBuffer();
    sql.write(
      'SELECT v.${HebrewGreekSchema.versesColId}, '
      't.${HebrewGreekSchema.textColText} ',
    );
    if (includeStrongs) {
      sql.write(', l.${HebrewGreekSchema.lemmaColLemma} ');
    }
    sql.write(
      'FROM ${HebrewGreekSchema.versesTable} v '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON v.${HebrewGreekSchema.versesColText} = t.${HebrewGreekSchema.textColId} ',
    );
    if (includeStrongs) {
      sql.write(
        'JOIN ${HebrewGreekSchema.lemmaTable} l '
        'ON v.${HebrewGreekSchema.versesColLemma} = l.${HebrewGreekSchema.lemmaColId} ',
      );
    }
    sql.write(
      'WHERE v.${HebrewGreekSchema.versesColId} >= ? AND v.${HebrewGreekSchema.versesColId} < ? '
      'ORDER BY v.${HebrewGreekSchema.versesColId} ASC',
    );

    final List<Map<String, dynamic>> words = await _database.rawQuery(
      sql.toString(),
      [lowerBound, upperBound],
    );

    return words
        .map(
          (word) => HebrewGreekWord(
            id: word[HebrewGreekSchema.versesColId],
            text: word[HebrewGreekSchema.textColText],
            strongsCode: word[HebrewGreekSchema.lemmaColLemma],
          ),
        )
        .toList();
  }

  /// Queries the database for unique normalized words starting with a given prefix,
  /// ordered by frequency (most frequent first).
  ///
  /// - [prefix]: The search prefix. Diacritics, punctuation, and case will be ignored.
  Future<List<String>> getWordsStartingWith(String prefix, {int? limit}) async {
    if (prefix.isEmpty) {
      return [];
    }

    final String normalizedPrefix = normalizeHebrewGreek(prefix);

    if (normalizedPrefix.isEmpty) {
      return [];
    }

    String sql =
        'SELECT DISTINCT ${HebrewGreekSchema.textColNormalized} '
        'FROM ${HebrewGreekSchema.textTable} '
        'WHERE ${HebrewGreekSchema.textColNormalized} LIKE ? '
        'ORDER BY ${HebrewGreekSchema.textColId} ASC';

    final pattern = '$normalizedPrefix%';
    final List<Object> arguments = [pattern];
    if (limit != null && limit > 0) {
      sql += ' LIMIT ?';
      arguments.add(limit);
    }

    final maps = await _database.rawQuery(sql, arguments);

    if (maps.isNotEmpty) {
      return maps
          .map((map) => map[HebrewGreekSchema.textColNormalized] as String)
          .toList();
    }

    return [];
  }

  /// Searches for verses containing one or more normalized words.
  ///
  /// If more than one word is provided, it returns verses that contain ALL of them.
  ///
  /// Returns a list of `Reference` objects for each matching verse.
  Future<List<Reference>> searchVersesByNormalizedWords(
    List<String> normalizedWords,
  ) async {
    // Return early for an empty search to avoid an invalid SQL query.
    if (normalizedWords.isEmpty) {
      return [];
    }

    // Using a Set handles duplicate search terms automatically.
    final uniqueWords = normalizedWords.toSet().toList();

    final placeholders = List.filled(uniqueWords.length, '?').join(', ');

    // This calculation creates a unique ID for each verse.
    // e.g., Genesis 1:1 -> 1001001
    final verseIdCalc = 'v.${HebrewGreekSchema.versesColId} / 100';

    final sql = '''
    SELECT
      $verseIdCalc AS verse_id
    FROM
      ${HebrewGreekSchema.versesTable} v
    INNER JOIN
      ${HebrewGreekSchema.textTable} t 
      ON v.${HebrewGreekSchema.versesColText} = t.${HebrewGreekSchema.textColId}
    WHERE
      t.${HebrewGreekSchema.textColNormalized} IN ($placeholders)
    GROUP BY
      verse_id
    HAVING
      COUNT(DISTINCT t.${HebrewGreekSchema.textColNormalized}) = ?
    ORDER BY
      verse_id ASC
    ''';

    final List<dynamic> arguments = [...uniqueWords, uniqueWords.length];

    final List<Map<String, dynamic>> maps = await _database.rawQuery(
      sql,
      arguments,
    );

    if (maps.isEmpty) {
      return [];
    }

    // Map the list of verse IDs to a list of Reference objects.
    return maps.map((map) {
      final int verseId = map['verse_id'] as int;

      // Decode the verseId into its components.
      final int bookId = verseId ~/ 1000000;
      final int remainder = verseId % 1000000;
      final int chapter = remainder ~/ 1000;
      final int verse = remainder % 1000;

      return Reference(bookId: bookId, chapter: chapter, verse: verse);
    }).toList();
  }
}
