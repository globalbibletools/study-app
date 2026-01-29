import 'dart:developer';
import 'dart:io';

import 'package:scripture/scripture_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

class BibleDatabase {
  BibleDatabase({required this.databaseName});

  /// 3-letter language code + underscore + version abbreviation
  ///
  /// Example: eng_bsb (English - Berean Standard Bible)
  final String databaseName;

  late Database _database;
  late PreparedStatement _insertVerseLine;

  void init() {
    _deleteDatabase();
    _database = sqlite3.open('$databaseName.db');
    _createTable();
    _initPreparedStatements();
  }

  void _deleteDatabase() {
    final filename = '$databaseName.db';
    final file = File(filename);
    if (file.existsSync()) {
      log('Deleting database file: $filename');
      file.deleteSync();
    }
  }

  void _createTable() {
    _database.execute(BibleSchema.createBibleTextTable);
  }

  void _initPreparedStatements() {
    _insertVerseLine = _database.prepare(BibleSchema.insertLine);
  }

  Future<void> populateTable() async {
    _ignoredTags.clear();
    int bookId = 0;
    int chapter = 0;
    int verse = 0;
    String? text;
    ParagraphFormat? format;

    final parentheses = RegExp(r'[()]');

    beginTransaction();

    for (String bookFilename in bibleBooks) {
      print('Processing: $bookFilename');
      chapter = 0;
      verse = 0;

      final file = File('lib/src/bible/data/$databaseName/$bookFilename');

      if (!file.existsSync()) {
        throw Exception('${file.path} does not exist');
      }

      final lines = await file.readAsLines();
      String oldMarker = '';
      for (String newLine in lines) {
        // split at a space or a newline and take the text before it
        String marker = newLine.split(RegExp(r'[ \n]'))[0];
        final remainder = newLine.substring(marker.length).trim();
        marker = marker.replaceAll(r'\', '');
        switch (marker) {
          case 'id': // book
            bookId = _getBookId(remainder);
            format = null;
            continue;
          case 'h': // book title
          case 'toc1': // book title
          case 'toc2': // book title
          case 'toc3': // short book title
          case 'mt1': // book title
          case 'mt2': // book title
          case 'imt1': // Introduction Major Title
          case 'imt2': // Introduction Major Title 2
          case 'imt3': // Introduction Major Title 3
          case 'ip': // Introduction Paragraph
          case 'ipi': // Introduction Paragraph Indented
          case 'ie': // Introduction End
          case 'is': // Introduction Section heading
          case 'is1': // Introduction Section heading 1
          case 'ib': // Introduction break
          case 'io1': // Introduction outline 1
          case 'io2': // Introduction outline 2
          case 'tr': // Table Row
          case 'th1': // Table column heading 1
          case 'th2': // Table column heading 2
          case 'tc1': // Table cell 1
          case 'tc2': // Table cell 2
          case 'tc3': // Table cell 3
          case 'rem': // Remarks/Comments
          case 'ide': // encoding
          case 'cl': // chapter label
            // ignore
            continue;
          case 'c': // chapter
            chapter = _getChapter(remainder);
            verse = 0;
            continue;
          case 'r': // cross reference
            format = ParagraphFormat.r;
            if (remainder.isEmpty) {
              continue;
            }
            // Strip parentheses from reference
            text = remainder.replaceAll(parentheses, '');
          case 's1': // section heading level 1
          case 's2': // section heading level 2
          case 'ms': // major section (Psalms)
          case 'ms1': // major section 1
          case 'ms2': // major section 2
          case 'mr': // major section range (Psalms)
          case 'qa': // Acrostic heading (Psalm 119)
          case 'm': // margin
          case 'pmo': // indented paragraph margin opening
          case 'li1': // list item level 1
          case 'li2': // list item level 2
          case 'q1': // poetry indentation level 1
          case 'q2': // poetry indentation level 2
          case 'qr': // right aligned
            format = ParagraphFormat.fromJson(marker);
            if (remainder.isEmpty) {
              continue;
            }
            text = remainder;
          case 'p': // paragraph
          case 'pi1': // indented paragraph level 1
            if (oldMarker == 'v' || oldMarker == 'r') {
              insertBreak(bookId: bookId, chapter: chapter, verse: verse);
            }
            format = ParagraphFormat.fromJson(marker);
            if (remainder.isEmpty) {
              continue;
            }
            text = remainder;
          case 'nb': // No Break (continuation of text from previous chapter)
            format = ParagraphFormat.m; // Use 'm' (no indent)
            if (remainder.isEmpty) {
              continue;
            }
            text = remainder;
          case 'v': // verse
            (verse, text) = _getVerse(remainder);
          case 'd': // descriptive title
            format = ParagraphFormat.d;
            if (remainder.isEmpty) {
              continue;
            }
            text = remainder;
            verse = 0;
          case 'b': // break
            // ignore unnecessary breaks after section headings
            if (oldMarker == 's1' || oldMarker == 's2') {
              continue;
            }
            format = ParagraphFormat.b;
            text = '';
          case 'pc': // centered
          case 'qc': // centered quote/poetry
            format = ParagraphFormat.pc;
            if (remainder.isEmpty) {
              continue;
            }
            text = remainder;
          default:
            throw Exception(
              'Unknown marker: $marker (chapter: $chapter, verse: $verse)',
            );
        }

        if (format == null) {
          print('Format null at: $marker (chapter: $chapter, verse: $verse)');
          return;
        }

        if (text.isNotEmpty) {
          text = _cleanText(text, bookId, chapter, verse);
        }

        insertVerseLine(
          bookId: bookId,
          chapter: chapter,
          verse: verse,
          text: text,
          format: format.id,
        );

        text = null;
        oldMarker = marker;
      }
    }

    commitTransaction();
    _printIgnoredTagsReport();
  }

  void _printIgnoredTagsReport() {
    if (_ignoredTags.isEmpty) return;

    print('\n--- Ignored Inline Markers Report ---');
    // Sort by count descending
    final sortedKeys = _ignoredTags.keys.toList()
      ..sort((a, b) => _ignoredTags[b]!.compareTo(_ignoredTags[a]!));

    for (final key in sortedKeys) {
      print('${key.padRight(10)} : ${_ignoredTags[key]}');
    }
    print('-------------------------------------\n');
  }

  void beginTransaction() {
    _database.execute('BEGIN TRANSACTION;');
  }

  void commitTransaction() {
    _database.execute('COMMIT;');
  }

  void insertBreak({
    required int bookId,
    required int chapter,
    required int verse,
  }) {
    insertVerseLine(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      text: '',
      format: 'b',
    );
  }

  void insertVerseLine({
    required int bookId,
    required int chapter,
    required int verse,
    required String text,
    required String format,
  }) {
    if (text.isEmpty && format != 'b') {
      throw Exception('Empty text for $bookId, $chapter, $verse');
    }
    final reference = _packReference(bookId, chapter, verse);
    _insertVerseLine.execute([reference, text, format]);
  }

  // BBCCCVVV packed int
  int _packReference(int bookId, int chapter, int verse) {
    return bookId * 1000000 + chapter * 1000 + verse;
  }

  int _getBookId(String textAfterMarker) {
    final index = textAfterMarker.indexOf(' ');
    String bookName;
    if (index == -1) {
      // No space found, the whole string is the book name (e.g., "GEN")
      bookName = textAfterMarker;
    } else {
      // Space found, take the substring before it
      bookName = textAfterMarker.substring(0, index);
    }
    if (!_bookAbbreviationToIdMap.containsKey(bookName)) {
      throw Exception('Unknown book abbreviation: "$bookName"');
    }
    return _bookAbbreviationToIdMap[bookName]!;
  }

  int _getChapter(String textAfterMarker) {
    return int.parse(textAfterMarker);
  }

  (int, String) _getVerse(String textAfterMarker) {
    final index = textAfterMarker.indexOf(' ');
    final verseNumber = int.parse(textAfterMarker.substring(0, index));
    final remainder = textAfterMarker.substring(index).trim();
    return (verseNumber, remainder);
  }

  final Map<String, int> _ignoredTags = {};

  String _cleanText(String input, int bookId, int chapter, int verse) {
    var text = input;

    // Helper to track counts
    void track(String marker) {
      // We strip the '*' to group opening (\wj) and closing (\wj*) tags together
      final key = marker.replaceAll('*', '');
      _ignoredTags[key] = (_ignoredTags[key] ?? 0) + 1;
    }

    // Remove Cross References (\x ... \x*) - Remove content entirely
    text = text.replaceAllMapped(RegExp(r'(\\x) .*?(\\x\*)'), (match) {
      track(match.group(1)!); // track \x
      track(match.group(2)!); // track \x*
      return ''; // remove entirely
    });

    // Remove Word Attributes (\w word|attributes\w*) - Keep word, remove attrs
    text = text.replaceAllMapped(RegExp(r'(\\\+?w) (.*?)\|.*?(\\\+?w\*)'), (
      match,
    ) {
      track(match.group(1)!); // track \w or \+w
      track(match.group(3)!); // track \w* or \+w*
      return match.group(2) ?? ''; // keep the word
    });

    // Remove Simple Word Tags (\w or \+w word\w*)
    text = text.replaceAllMapped(RegExp(r'(\\\+?w) (.*?)(\\\+?w\*)'), (match) {
      track(match.group(1)!);
      track(match.group(3)!);
      return match.group(2) ?? '';
    });

    // Remove generic styling tags (keep the text inside)
    // wj: words of Jesus
    // qs: Selah
    // it: italic
    text = text.replaceAllMapped(RegExp(r'\\(wj|qs|it)\*?'), (match) {
      final marker = match.group(0)!;
      track(marker);
      return ''; // remove tag, keep text
    });

    // Clean up any double spaces created by removals
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Detect Unknown Markers
    if (text.contains('\\')) {
      final matches = RegExp(r'\\[a-z]+\d?(\*)?').allMatches(text);
      for (final m in matches) {
        final marker = m.group(0);

        // whitelist allowed markers (like footnotes)
        const allowed = ['\\f', '\\fr', '\\ft', '\\f*', '\\fq'];

        if (!allowed.contains(marker)) {
          track(marker!);
          print(
            '⚠️ WARNING: Unhandled inline marker "$marker" found at '
            'Book: $bookId, Ch: $chapter, V: $verse\n'
            '   Text: "$text"',
          );
        }
      }
    }
    return text;
  }

  void dispose() {
    _insertVerseLine.dispose();
    _database.dispose();
  }
}

const List<String> bibleBooks = [
  'gen.usfm', // Genesis
  'exo.usfm', // Exodus
  'lev.usfm', // Leviticus
  'num.usfm', // Numbers
  'deu.usfm', // Deuteronomy
  'jos.usfm', // Joshua
  'jdg.usfm', // Judges
  'rut.usfm', // Ruth
  '1sa.usfm', // 1 Samuel
  '2sa.usfm', // 2 Samuel
  '1ki.usfm', // 1 Kings
  '2ki.usfm', // 2 Kings
  '1ch.usfm', // 1 Chronicles
  '2ch.usfm', // 2 Chronicles
  'ezr.usfm', // Ezra
  'neh.usfm', // Nehemiah
  'est.usfm', // Esther
  'job.usfm', // Job
  'psa.usfm', // Psalms
  'pro.usfm', // Proverbs
  'ecc.usfm', // Ecclesiastes
  'sng.usfm', // Song of Solomon
  'isa.usfm', // Isaiah
  'jer.usfm', // Jeremiah
  'lam.usfm', // Lamentations
  'ezk.usfm', // Ezekiel
  'dan.usfm', // Daniel
  'hos.usfm', // Hosea
  'jol.usfm', // Joel
  'amo.usfm', // Amos
  'oba.usfm', // Obadiah
  'jon.usfm', // Jonah
  'mic.usfm', // Micah
  'nam.usfm', // Nahum
  'hab.usfm', // Habakkuk
  'zep.usfm', // Zephaniah
  'hag.usfm', // Haggai
  'zec.usfm', // Zechariah
  'mal.usfm', // Malachi
  'mat.usfm', // Matthew
  'mrk.usfm', // Mark
  'luk.usfm', // Luke
  'jhn.usfm', // John
  'act.usfm', // Acts
  'rom.usfm', // Romans
  '1co.usfm', // 1 Corinthians
  '2co.usfm', // 2 Corinthians
  'gal.usfm', // Galatians
  'eph.usfm', // Ephesians
  'php.usfm', // Philippians
  'col.usfm', // Colossians
  '1th.usfm', // 1 Thessalonians
  '2th.usfm', // 2 Thessalonians
  '1ti.usfm', // 1 Timothy
  '2ti.usfm', // 2 Timothy
  'tit.usfm', // Titus
  'phm.usfm', // Philemon
  'heb.usfm', // Hebrews
  'jas.usfm', // James
  '1pe.usfm', // 1 Peter
  '2pe.usfm', // 2 Peter
  '1jn.usfm', // 1 John
  '2jn.usfm', // 2 John
  '3jn.usfm', // 3 John
  'jud.usfm', // Jude
  'rev.usfm', // Revelation
];

final _bookAbbreviationToIdMap = {
  'GEN': 1,
  'EXO': 2,
  'LEV': 3,
  'NUM': 4,
  'DEU': 5,
  'JOS': 6,
  'JDG': 7,
  'RUT': 8,
  '1SA': 9,
  '2SA': 10,
  '1KI': 11,
  '2KI': 12,
  '1CH': 13,
  '2CH': 14,
  'EZR': 15,
  'NEH': 16,
  'EST': 17,
  'JOB': 18,
  'PSA': 19,
  'PRO': 20,
  'ECC': 21,
  'SNG': 22,
  'ISA': 23,
  'JER': 24,
  'LAM': 25,
  'EZK': 26,
  'DAN': 27,
  'HOS': 28,
  'JOL': 29,
  'AMO': 30,
  'OBA': 31,
  'JON': 32,
  'MIC': 33,
  'NAM': 34,
  'HAB': 35,
  'ZEP': 36,
  'HAG': 37,
  'ZEC': 38,
  'MAL': 39,
  'MAT': 40,
  'MRK': 41,
  'LUK': 42,
  'JHN': 43,
  'ACT': 44,
  'ROM': 45,
  '1CO': 46,
  '2CO': 47,
  'GAL': 48,
  'EPH': 49,
  'PHP': 50,
  'COL': 51,
  '1TH': 52,
  '2TH': 53,
  '1TI': 54,
  '2TI': 55,
  'TIT': 56,
  'PHM': 57,
  'HEB': 58,
  'JAS': 59,
  '1PE': 60,
  '2PE': 61,
  '1JN': 62,
  '2JN': 63,
  '3JN': 64,
  'JUD': 65,
  'REV': 66,
};
