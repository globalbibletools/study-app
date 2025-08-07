import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LexiconsDatabase {
  static const _hebrewDatabaseName = 'sdbh.db';
  static const _greekDatabaseName = 'sdbg.db';
  static const _hebrewDbVersion = 1;
  static const _greekDbVersion = 1;
  late Database _hebrewDatabase;
  late Database _greekDatabase;

  Future<void> init() async {
    var databasesPath = await getDatabasesPath();
    _hebrewDatabase = await _init(
      databasesPath,
      _hebrewDatabaseName,
      _hebrewDbVersion,
    );
    _greekDatabase = await _init(
      databasesPath,
      _greekDatabaseName,
      _greekDbVersion,
    );
  }

  Future<Database> _init(
    String databasesPath,
    String databaseName,
    int databaseVersion,
  ) async {
    var path = join(databasesPath, databaseName);
    var exists = await databaseExists(path);

    if (!exists) {
      log('Creating new copy of $databaseName from assets');
      await _copyDatabaseFromAssets(path, databaseName);
    } else {
      // Check if database needs update
      var currentVersion = await _getDatabaseVersion(path);
      if (currentVersion != databaseVersion) {
        log(
          'Updating Hebrew/Greek database from version $currentVersion to $databaseVersion',
        );
        await deleteDatabase(path);
        await _copyDatabaseFromAssets(path, databaseName);
      } else {
        log("Opening existing $databaseName database");
      }
    }
    return await openDatabase(path, version: databaseVersion);
  }

  Future<int> _getDatabaseVersion(String path) async {
    var db = await openDatabase(path);
    var version = await db.getVersion();
    await db.close();
    return version;
  }

  Future<void> _copyDatabaseFromAssets(String path, String name) async {
    await Directory(dirname(path)).create(recursive: true);
    final data = await rootBundle.load(join('assets/databases', name));
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  /// Retrieves all the meanings for a given Strong's code.
  ///
  /// The [strongsCode] should start with 'H' for Hebrew or 'G' for Greek.
  /// This method queries the appropriate database and returns a list of all
  /// matching meaning entries.
  Future<List<LexiconMeaning>> getMeaningsForStrongs(String strongsCode) async {
    // Determine which database to use based on the prefix of the Strong's code.
    final db = strongsCode.startsWith('H') ? _hebrewDatabase : _greekDatabase;

    // Execute the predefined query to get meanings for the given Strong's code.
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      LexiconSchema.getMeaningsForStrongsQuery,
      [strongsCode],
    );

    return maps.map((map) => LexiconMeaning.fromMap(map)).toList();
  }
}

/// A data model class that represents a single lexicon meaning entry with its
/// associated grammar text.
class LexiconMeaning {
  final int lexId;
  final String? grammar;
  final String lemma;
  final String? definitionShort;
  final String? comments;
  final String glosses;

  int get lemmaId => lexId ~/ LexiconSchema.lemmaIdOffset;

  LexiconMeaning({
    required this.lexId,
    this.grammar,
    required this.lemma,
    this.definitionShort,
    this.comments,
    required this.glosses,
  });

  /// A factory constructor for creating a new `LexiconMeaning` instance
  /// from a map returned by the database query.
  factory LexiconMeaning.fromMap(Map<String, dynamic> map) {
    return LexiconMeaning(
      lexId: map[LexiconSchema.meaningsColLexId],
      grammar: map[LexiconSchema.grammarColText],
      lemma: map[LexiconSchema.meaningsColLemma],
      definitionShort: map[LexiconSchema.meaningsColDefinitionShort],
      comments: map[LexiconSchema.meaningsColComments],
      glosses: map[LexiconSchema.meaningsColGlosses],
    );
  }

  @override
  String toString() {
    return 'LexiconMeaning{lexId: $lexId, lemma: $lemma, grammar: $grammar, definition: $definitionShort}';
  }
}
