import 'dart:developer';
import 'dart:io';

import 'package:database_builder/database_builder.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LexiconsDatabase {
  static const _hebrewDatabaseName = 'sdbh.db';
  static const _greekDatabaseName = 'sdbg.db';
  static const _hebrewDbVersion = 2;
  static const _greekDbVersion = 2;
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

  factory LexiconMeaning.fromMap(Map<String, dynamic> map) {
    final definition = map[LexiconSchema.meaningsColDefinitionShort];
    final comments = map[LexiconSchema.meaningsColComments];
    return LexiconMeaning(
      lexId: map[LexiconSchema.meaningsColLexId],
      grammar: map[LexiconSchema.grammarColText],
      lemma: map[LexiconSchema.meaningsColLemma],
      definitionShort: _replaceReferences(definition),
      comments: _replaceReferences(comments),
      glosses: map[LexiconSchema.meaningsColGlosses],
    );
  }

  static String? _replaceReferences(String? text) {
    if (text == null) return null;

    // replace {L:ἄρχω<SDBG:ἄρχω:000000>} -> ἄρχω
    // replace {L:Bashan<SDBH:בָּשָׁן>} -> Bashan (בָּשָׁן)
    var regex = RegExp(r'\{L:(.*?)<SDB[GH]:([^:]*)(:.*?)?>\}');
    String modifiedString = text.replaceAllMapped(regex, (match) {
      final part1 = match.group(1);
      final part2 = match.group(2);
      if (part1 == part2) {
        return part1.toString();
      }
      return '$part1 ($part2)';
    });

    // replace {S:06600301400040} -> Revelation 3:14
    regex = RegExp(r'\{S:(\d{3})(\d{3})(\d{3})\d{5}\}');
    modifiedString = modifiedString.replaceAllMapped(regex, (match) {
      int bookId = int.parse(match.group(1)!);
      final book = _bookIdToFullNameMap[bookId];
      int chapter = int.parse(match.group(2)!);
      int verse = int.parse(match.group(3)!);
      return '$book $chapter:$verse';
    });

    return modifiedString;
  }

  @override
  String toString() {
    return 'LexiconMeaning{lexId: $lexId, lemma: $lemma, grammar: $grammar, definition: $definitionShort}';
  }
}

const _bookIdToFullNameMap = {
  1: 'Genesis',
  2: 'Exodus',
  3: 'Leviticus',
  4: 'Numbers',
  5: 'Deuteronomy',
  6: 'Joshua',
  7: 'Judges',
  8: 'Ruth',
  9: '1 Samuel',
  10: '2 Samuel',
  11: '1 Kings',
  12: '2 Kings',
  13: '1 Chronicles',
  14: '2 Chronicles',
  15: 'Ezra',
  16: 'Nehemiah',
  17: 'Esther',
  18: 'Job',
  19: 'Psalm',
  20: 'Proverbs',
  21: 'Ecclesiastes',
  22: 'Song of Solomon',
  23: 'Isaiah',
  24: 'Jeremiah',
  25: 'Lamentations',
  26: 'Ezekiel',
  27: 'Daniel',
  28: 'Hosea',
  29: 'Joel',
  30: 'Amos',
  31: 'Obadiah',
  32: 'Jonah',
  33: 'Micah',
  34: 'Nahum',
  35: 'Habakkuk',
  36: 'Zephaniah',
  37: 'Haggai',
  38: 'Zechariah',
  39: 'Malachi',
  40: 'Matthew',
  41: 'Mark',
  42: 'Luke',
  43: 'John',
  44: 'Acts',
  45: 'Romans',
  46: '1 Corinthians',
  47: '2 Corinthians',
  48: 'Galatians',
  49: 'Ephesians',
  50: 'Philippians',
  51: 'Colossians',
  52: '1 Thessalonians',
  53: '2 Thessalonians',
  54: '1 Timothy',
  55: '2 Timothy',
  56: 'Titus',
  57: 'Philemon',
  58: 'Hebrews',
  59: 'James',
  60: '1 Peter',
  61: '2 Peter',
  62: '1 John',
  63: '2 John',
  64: '3 John',
  65: 'Jude',
  66: 'Revelation',
};
