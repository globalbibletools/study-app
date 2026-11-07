import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:database_builder/database_builder.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/bible/bible_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Reference packed integer encoding & decoding', () {
    test('encodes Reference into 32-bit BBCCCVVV integer', () {
      const ref = Reference(bookId: 8, chapter: 4, verse: 17);
      expect(ref.toPackedInt, 8004017);
    });

    test('decodes 32-bit BBCCCVVV integer into Reference', () {
      final ref = Reference.fromPackedInt(8004017);
      expect(ref.bookId, 8);
      expect(ref.chapter, 4);
      expect(ref.verse, 17);
    });

    test('round-trip packing and unpacking preserves values', () {
      for (final bookId in [1, 19, 40, 66]) {
        for (final chapter in [1, 23, 119, 150]) {
          for (final verse in [1, 15, 99, 176]) {
            final original = Reference(
              bookId: bookId,
              chapter: chapter,
              verse: verse,
            );
            final unpacked = Reference.fromPackedInt(original.toPackedInt);
            expect(unpacked, equals(original));
          }
        }
      }
    });
  });

  group('BibleDatabase.getVerses', () {
    late String dbPath;
    late Database rawDb;
    late BibleDatabase bibleDb;

    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp('bible_test_');
      dbPath = p.join(tempDir.path, 'test_bible.db');

      rawDb = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${BibleSchema.bibleTextTable} (
              ${BibleSchema.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${BibleSchema.colReference} INTEGER NOT NULL,
              ${BibleSchema.colText} TEXT NOT NULL,
              ${BibleSchema.colFormat} TEXT NOT NULL
            );
          ''');
        },
      );

      // Seed test data
      // Ruth 4:17 single line
      await rawDb.insert(BibleSchema.bibleTextTable, {
        BibleSchema.colReference: 8004017,
        BibleSchema.colText:
            'And the women said: There is a son born to Naomi.',
        BibleSchema.colFormat: 'p',
      });

      // Psalm 23:1 multi-line poetry (q1, q2) + heading (s1)
      await rawDb.insert(BibleSchema.bibleTextTable, {
        BibleSchema.colReference: 19023000,
        BibleSchema.colText: 'The Lord is My Shepherd',
        BibleSchema.colFormat: 's1',
      });
      await rawDb.insert(BibleSchema.bibleTextTable, {
        BibleSchema.colReference: 19023001,
        BibleSchema.colText: 'The LORD is my shepherd;',
        BibleSchema.colFormat: 'q1',
      });
      await rawDb.insert(BibleSchema.bibleTextTable, {
        BibleSchema.colReference: 19023001,
        BibleSchema.colText: 'I shall not want.',
        BibleSchema.colFormat: 'q2',
      });

      // Close raw handle and open with BibleDatabase
      await rawDb.close();
      bibleDb = await BibleDatabase.open(dbPath);
    });

    tearDown(() async {
      await bibleDb.close();
      final file = File(dbPath);
      if (await file.exists()) {
        await file.parent.delete(recursive: true);
      }
    });

    test('empty reference list returns empty map', () async {
      final verses = await bibleDb.getVerses([]);
      expect(verses, isEmpty);
    });

    test('queries single verse correctly', () async {
      const ruth417 = Reference(bookId: 8, chapter: 4, verse: 17);
      final verses = await bibleDb.getVerses([ruth417]);
      expect(verses.length, 1);
      expect(
        verses[ruth417],
        'And the women said: There is a son born to Naomi.',
      );
    });

    test(
      'joins multi-row poetic lines with space and excludes section headers',
      () async {
        const psalm231 = Reference(bookId: 19, chapter: 23, verse: 1);
        final verses = await bibleDb.getVerses([psalm231]);
        expect(verses.length, 1);
        expect(verses[psalm231], 'The LORD is my shepherd; I shall not want.');
      },
    );

    test(
      'queries multiple references and ignores unseeded references',
      () async {
        const ruth417 = Reference(bookId: 8, chapter: 4, verse: 17);
        const psalm231 = Reference(bookId: 19, chapter: 23, verse: 1);
        const missingRef = Reference(bookId: 1, chapter: 1, verse: 1);

        final verses = await bibleDb.getVerses([ruth417, psalm231, missingRef]);
        expect(verses.length, 2);
        expect(verses.containsKey(missingRef), isFalse);
      },
    );

    test('handles large reference lists (> 500) by chunking safely', () async {
      // Generate 550 references
      final refs = <Reference>[];
      for (var i = 1; i <= 550; i++) {
        refs.add(Reference(bookId: 19, chapter: 1, verse: i));
      }
      // Should execute without throwing SQLite parameter limit exceptions
      final verses = await bibleDb.getVerses(refs);
      expect(verses, isA<Map<Reference, String>>());
    });

    test('stripParatext removes footnotes and character markers cleanly', () {
      const raw =
          r'In the beginning \f + \ft Some footnote\f* God created \add the heavens\add* and the earth.';
      final cleaned = BibleDatabase.stripParatext(raw);
      expect(
        cleaned,
        'In the beginning God created the heavens and the earth.',
      );
    });
  });
}
