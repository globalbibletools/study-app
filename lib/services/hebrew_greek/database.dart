import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';

class HebrewGreekDatabase {
  static const _databaseName = 'hebrew_greek.db';
  static const _databaseVersion = HebrewGreekSchema.databaseVersion;
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
    final List<Map<String, dynamic>> rows = await _database.rawQuery(
      'SELECT w.${HebrewGreekSchema.wordsColWordId}, '
      'v.${HebrewGreekSchema.versesColBook}, '
      'v.${HebrewGreekSchema.versesColChapter}, '
      'v.${HebrewGreekSchema.versesColVerse}, '
      't.${HebrewGreekSchema.textColText} '
      'FROM ${HebrewGreekSchema.wordsTable} w '
      'JOIN ${HebrewGreekSchema.versesTable} v '
      'ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId} '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON w.${HebrewGreekSchema.wordsColText} = t.${HebrewGreekSchema.textColId} '
      'WHERE v.${HebrewGreekSchema.versesColBook} = ? '
      'AND v.${HebrewGreekSchema.versesColChapter} = ? '
      'ORDER BY w.${HebrewGreekSchema.wordsColWordId} ASC',
      [bookId, chapter],
    );

    return rows.map(_toHebrewGreekWord).toList();
  }

  Future<HebrewGreekWord?> getWordForId(String wordId) async {
    final List<Map<String, dynamic>> rows = await _database.rawQuery(
      'SELECT w.${HebrewGreekSchema.wordsColWordId}, '
      'v.${HebrewGreekSchema.versesColBook}, '
      'v.${HebrewGreekSchema.versesColChapter}, '
      'v.${HebrewGreekSchema.versesColVerse}, '
      't.${HebrewGreekSchema.textColText} '
      'FROM ${HebrewGreekSchema.wordsTable} w '
      'JOIN ${HebrewGreekSchema.versesTable} v '
      'ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId} '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON w.${HebrewGreekSchema.wordsColText} = t.${HebrewGreekSchema.textColId} '
      'WHERE w.${HebrewGreekSchema.wordsColWordId} = ?',
      [wordId],
    );
    if (rows.isEmpty) return null;
    return _toHebrewGreekWord(rows.first);
  }

  HebrewGreekWord _toHebrewGreekWord(Map<String, dynamic> row) {
    return HebrewGreekWord(
      id: row[HebrewGreekSchema.wordsColWordId] as String,
      reference: Reference(
        bookId: row[HebrewGreekSchema.versesColBook] as int,
        chapter: row[HebrewGreekSchema.versesColChapter] as int,
        verse: row[HebrewGreekSchema.versesColVerse] as int,
      ),
      text: row[HebrewGreekSchema.textColText] as String,
      strongsCode: row[HebrewGreekSchema.strongsColCode] as String?,
    );
  }

  Future<(String, String)?> getStrongsAndGrammar(String wordId) async {
    final List<Map<String, dynamic>> result = await _database.rawQuery(
      '''SELECT l.${HebrewGreekSchema.strongsColCode}, g.${HebrewGreekSchema.grammarColGrammar}
      FROM ${HebrewGreekSchema.wordsTable} w
      JOIN ${HebrewGreekSchema.strongsTable} l
      ON w.${HebrewGreekSchema.wordsColStrongs} = l.${HebrewGreekSchema.strongsColId}
      JOIN ${HebrewGreekSchema.grammarTable} g
      ON w.${HebrewGreekSchema.wordsColGrammar} = g.${HebrewGreekSchema.grammarColId}
      WHERE w.${HebrewGreekSchema.wordsColWordId} = ?''',
      [wordId],
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    final lemma = row[HebrewGreekSchema.strongsColCode] as String;
    final grammar = row[HebrewGreekSchema.grammarColGrammar] as String;
    return (lemma, grammar);
  }

  Future<List<Reference>> allVersesForStrongsCode(String strongsCode) async {
    final List<Map<String, dynamic>> maps = await _database.rawQuery(
      '''SELECT DISTINCT
        v.${HebrewGreekSchema.versesColBook},
        v.${HebrewGreekSchema.versesColChapter},
        v.${HebrewGreekSchema.versesColVerse}
      FROM ${HebrewGreekSchema.wordsTable} AS w
      INNER JOIN ${HebrewGreekSchema.versesTable} AS v
      ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId}
      INNER JOIN ${HebrewGreekSchema.strongsTable} AS l
      ON w.${HebrewGreekSchema.wordsColStrongs} = l.${HebrewGreekSchema.strongsColId}
      WHERE l.${HebrewGreekSchema.strongsColCode} = ?
      ORDER BY
        v.${HebrewGreekSchema.versesColBook},
        v.${HebrewGreekSchema.versesColChapter},
        v.${HebrewGreekSchema.versesColVerse}
      ''',
      [strongsCode],
    );

    return maps.map(_toReference).toList();
  }

  Reference _toReference(Map<String, dynamic> map) {
    return Reference(
      bookId: map[HebrewGreekSchema.versesColBook] as int,
      chapter: map[HebrewGreekSchema.versesColChapter] as int,
      verse: map[HebrewGreekSchema.versesColVerse] as int,
    );
  }

  Future<String?> strongsCodeRoot(String strongsCode) async {
    final String sql =
        '''
    SELECT ${HebrewGreekSchema.strongsColRoot}
    FROM ${HebrewGreekSchema.strongsTable}
    WHERE ${HebrewGreekSchema.strongsColCode} = ?
    LIMIT 1
    ''';

    final result = await _database.rawQuery(sql, [strongsCode]);

    if (result.isNotEmpty) {
      return result.first[HebrewGreekSchema.strongsColRoot] as String?;
    }

    return null;
  }

  Future<List<HebrewGreekWord>> wordsForVerse(
    Reference reference, {
    bool includeStrongs = false,
  }) async {
    final sql = StringBuffer();
    sql.write(
      'SELECT w.${HebrewGreekSchema.wordsColWordId}, '
      'v.${HebrewGreekSchema.versesColBook}, '
      'v.${HebrewGreekSchema.versesColChapter}, '
      'v.${HebrewGreekSchema.versesColVerse}, '
      't.${HebrewGreekSchema.textColText} ',
    );
    if (includeStrongs) {
      sql.write(', l.${HebrewGreekSchema.strongsColCode} ');
    }
    sql.write(
      'FROM ${HebrewGreekSchema.wordsTable} w '
      'JOIN ${HebrewGreekSchema.versesTable} v '
      'ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId} '
      'JOIN ${HebrewGreekSchema.textTable} t '
      'ON w.${HebrewGreekSchema.wordsColText} = t.${HebrewGreekSchema.textColId} ',
    );
    if (includeStrongs) {
      sql.write(
        'JOIN ${HebrewGreekSchema.strongsTable} l '
        'ON w.${HebrewGreekSchema.wordsColStrongs} = l.${HebrewGreekSchema.strongsColId} ',
      );
    }
    sql.write(
      'WHERE v.${HebrewGreekSchema.versesColBook} = ? '
      'AND v.${HebrewGreekSchema.versesColChapter} = ? '
      'AND v.${HebrewGreekSchema.versesColVerse} = ? '
      'ORDER BY w.${HebrewGreekSchema.wordsColWordId} ASC',
    );

    final List<Map<String, dynamic>> words = await _database.rawQuery(
      sql.toString(),
      [reference.bookId, reference.chapter, reference.verse],
    );

    return words.map(_toHebrewGreekWord).toList();
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

    final sql =
        '''
    SELECT
      v.${HebrewGreekSchema.versesColBook},
      v.${HebrewGreekSchema.versesColChapter},
      v.${HebrewGreekSchema.versesColVerse}
    FROM
      ${HebrewGreekSchema.wordsTable} w
    INNER JOIN
      ${HebrewGreekSchema.versesTable} v
      ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId}
    INNER JOIN
      ${HebrewGreekSchema.textTable} t
      ON w.${HebrewGreekSchema.wordsColText} = t.${HebrewGreekSchema.textColId}
    WHERE
      t.${HebrewGreekSchema.textColNormalized} IN ($placeholders)
    GROUP BY
      v.${HebrewGreekSchema.versesColVerseId}
    HAVING
      COUNT(DISTINCT t.${HebrewGreekSchema.textColNormalized}) = ?
    ORDER BY
      v.${HebrewGreekSchema.versesColBook},
      v.${HebrewGreekSchema.versesColChapter},
      v.${HebrewGreekSchema.versesColVerse}
    ''';

    final List<dynamic> arguments = [...uniqueWords, uniqueWords.length];

    final List<Map<String, dynamic>> maps = await _database.rawQuery(
      sql,
      arguments,
    );

    if (maps.isEmpty) {
      return [];
    }

    return maps.map(_toReference).toList();
  }

  /// Searches for all instances of a word, ignoring punctuation and capitalization.
  ///
  /// Returns a list of unique [Reference]s for the verses that contain a match.
  Future<List<Reference>> searchExactMatchNoPunctuation(String query) async {
    query = removePunctuation(query);

    if (query.isEmpty) {
      return [];
    }

    // Join words -> text (for the match) -> verses (for the reference), so the
    // result is a list of verse references rather than word ids that must be
    // decoded.
    const String sql =
        '''
      SELECT DISTINCT
        v.${HebrewGreekSchema.versesColBook},
        v.${HebrewGreekSchema.versesColChapter},
        v.${HebrewGreekSchema.versesColVerse}
      FROM ${HebrewGreekSchema.wordsTable} AS w
      INNER JOIN ${HebrewGreekSchema.textTable} AS t
      ON w.${HebrewGreekSchema.wordsColText} = t.${HebrewGreekSchema.textColId}
      INNER JOIN ${HebrewGreekSchema.versesTable} AS v
      ON w.${HebrewGreekSchema.wordsColVerseId} = v.${HebrewGreekSchema.versesColVerseId}
      WHERE t.${HebrewGreekSchema.textColNoPunctuation} = ?
      ORDER BY
        v.${HebrewGreekSchema.versesColBook},
        v.${HebrewGreekSchema.versesColChapter},
        v.${HebrewGreekSchema.versesColVerse}
    ''';

    final maps = await _database.rawQuery(sql, [query]);

    return maps.map(_toReference).toList();
  }
}
