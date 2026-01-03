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
    int bookId = 0;
    int chapter = 0;
    int verse = 0;
    String? text;
    ParagraphFormat? format;

    final parentheses = RegExp(r'[()]');

    for (String bookFilename in bibleBooks) {
      print('Processing: $bookFilename');
      final file = File('lib/src/bible/data/$databaseName/$bookFilename');

      if (!file.existsSync()) {
        throw Exception('${file.path} does not exist');
      }

      _database.execute('BEGIN TRANSACTION;');

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
          case 'mt1': // book title
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
            const habakkuk = 35;
            if (bookId == habakkuk && chapter == 3 && verse == 19) {
              // This should really be fixed in the original USFM file,
              // but we need to make it centered and italic like TextType.d.
              format = ParagraphFormat.d;
              text = _removeItalicMarkers(remainder);
            } else {
              format = ParagraphFormat.pc;
              if (remainder.isEmpty) {
                continue;
              }
              text = remainder;
            }
          default:
            throw Exception(
              'Unknown marker: $marker (chapter: $chapter, verse: $verse)',
            );
        }

        if (format == null) {
          print('Format null at: $marker (chapter: $chapter, verse: $verse)');
          return;
        }

        final reference = _packReference(bookId, chapter, verse);
        _insertVerseLine.execute([reference, text, format.id]);

        text = null;
        oldMarker = marker;
      }

      _database.execute('COMMIT;');
    }
  }

  String _removeItalicMarkers(String text) {
    // Original: \it For the choirmaster. With stringed instruments. \it*
    // Desired: For the choirmaster. With stringed instruments.
    final modifiedText = text.replaceAll(r'\it*', '').replaceAll(r'\it', '');
    return modifiedText.trim();
  }

  // BBCCCVVV packed int
  int _packReference(int bookId, int chapter, int verse) {
    return bookId * 1000000 + chapter * 1000 + verse;
  }

  int _getBookId(String textAfterMarker) {
    final index = textAfterMarker.indexOf(' ');
    final bookName = textAfterMarker.substring(0, index);
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

  /// Extracts the footnote from the text.
  ///
  /// The text may contain multiple footnotes. Each footnote is separated
  /// by a \n newline. The index and the footnote text are separated by a #.
  /// Example: "But springs \f + \fr 2:6 \ft Or mist\f* welled up from the earth \f + \fr 2:6 \ft Or land\f* and watered the whole surface of the ground. "
  /// New text: "But springs welled up from the earth and watered the whole surface of the ground. "
  /// The output will be:
  /// footnote: 11#Or mist\n36#Or land
  /// The indexes are exclusive, meaning the footnote text should be inserted before the index.
  (String outputText, String? footnote) extractFootnote(String text) {
    if (!text.contains('\\f')) {
      return (text, null);
    }

    final footnotes = <String>[];
    var modifiedText = text;

    while (modifiedText.contains('\\f')) {
      final startIndex = modifiedText.indexOf('\\f');
      final endIndex = modifiedText.indexOf('\\f*', startIndex) + 3;

      if (endIndex == -1) {
        throw Exception('Malformed footnote: missing closing tag');
      }

      final footnote = modifiedText.substring(startIndex, endIndex);
      final ftIndex = footnote.indexOf('\\ft');
      var footnoteIndex = modifiedText.indexOf('\\f', startIndex);
      // if a footnote comes after a space, the index is shifted by one to the left.
      // This is so that footnote markers may be inserted directly after a word.
      if (footnoteIndex > 0 && modifiedText[footnoteIndex - 1] == ' ') {
        footnoteIndex--;
      }
      final footnoteText = footnote
          .substring(ftIndex + 4, footnote.length - 3)
          .trim();
      footnotes.add('$footnoteIndex#$footnoteText');
      // Remove footnote from text
      modifiedText = modifiedText
          .replaceRange(startIndex, endIndex, '')
          .replaceAll('  ', ' ');
    }

    return (modifiedText.trim(), footnotes.join('\n'));
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
