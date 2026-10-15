import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/hebrew_greek/hebrew_grammar.dart';

void main() {
  group('parseHebrewGrammar', () {
    test('expands a noun', () {
      expect(parseHebrewGrammar('N-csc'), 'noun: common singular construct');
      expect(parseHebrewGrammar('N-mp'), 'noun: masculine plural');
      expect(parseHebrewGrammar('N-fsd'), 'noun: feminine singular determined');
      expect(parseHebrewGrammar('N-cdc'), 'noun: common dual construct');
    });

    test('expands a proper noun', () {
      expect(
        parseHebrewGrammar('N-proper-fs'),
        'noun: proper name, feminine singular',
      );
      expect(
        parseHebrewGrammar('N-proper-gms'),
        'noun: proper name, gentilic masculine singular',
      );
    });

    test('expands an adjective', () {
      expect(
        parseHebrewGrammar('Adj-fpc'),
        'adjective: feminine plural construct',
      );
    });

    test('expands a number', () {
      expect(
        parseHebrewGrammar('Number-ofs'),
        'number: ordinal feminine singular',
      );
      expect(
        parseHebrewGrammar('Number-omsd'),
        'number: ordinal masculine singular determined',
      );
    });

    test('expands a finite verb', () {
      expect(
        parseHebrewGrammar('V-Qal-Perf-3ms'),
        'verb: Qal stem (simple active), perfect, '
        'third-person masculine singular',
      );
    });

    test('expands a participle', () {
      expect(
        parseHebrewGrammar('V-Hifil-Prtcpl-msc'),
        'verb: Hifil stem (causative active), participle, '
        'masculine singular construct',
      );
    });

    test('expands an infinitive absolute', () {
      expect(
        parseHebrewGrammar('V-Nifal-InfAbs'),
        'verb: Nifal stem (simple passive), infinitive absolute',
      );
    });

    test('expands a consecutive imperfect', () {
      expect(
        parseHebrewGrammar('V-Qal-ConsecImperf-3mp'),
        'verb: Qal stem (simple active), consecutive imperfect, '
        'third-person masculine plural',
      );
    });

    test('expands a jussive and cohortative', () {
      expect(
        parseHebrewGrammar('V-Piel-Imperf.Jus-3ms'),
        'verb: Piel stem (intensive active), imperfect jussive, '
        'third-person masculine singular',
      );
      expect(
        parseHebrewGrammar('V-Qal-ConjImperf.Cohort-1cs'),
        'verb: Qal stem (simple active), '
        'conjunctive imperfect cohortative, first-person common singular',
      );
    });

    test('expands a prefixed conjunction', () {
      expect(parseHebrewGrammar('Conj-w'), 'conjunction: prefix waw ("and")');
    });

    test('expands a prefixed preposition', () {
      expect(
        parseHebrewGrammar('Prep-b'),
        'preposition: prefix beth ("in, with, by")',
      );
      expect(parseHebrewGrammar('Prep-m'), 'preposition: prefix mem ("from")');
    });

    test('expands an adverb with a negative particle', () {
      expect(parseHebrewGrammar('Adv-NegPrt'), 'adverb: negative particle');
    });

    test('expands a pronoun', () {
      expect(
        parseHebrewGrammar('Pro-3ms'),
        'pronoun: third-person masculine singular',
      );
      expect(parseHebrewGrammar('Pro-r'), 'pronoun: relative particle');
    });

    test('expands a bare pronominal suffix', () {
      expect(parseHebrewGrammar('3ms'), 'third-person masculine singular');
      expect(parseHebrewGrammar('1cs'), 'first-person common singular');
      expect(
        parseHebrewGrammar('2mse2'),
        'second-person masculine singular, emphatic (suffix-type 2)',
      );
    });

    test('expands a bare head', () {
      expect(parseHebrewGrammar('Art'), 'article');
      expect(parseHebrewGrammar('DirObjM'), 'direct-object marker with maqqēf');
      expect(parseHebrewGrammar('Interjection'), 'interjection');
      expect(parseHebrewGrammar('Interrog'), 'interrogative');
    });

    test('returns null for Greek codes', () {
      expect(parseHebrewGrammar('N....NFS'), isNull);
      expect(parseHebrewGrammar('V-AIA-1P'), isNull);
      expect(parseHebrewGrammar('N-NFS'), isNull);
    });

    test('returns null for malformed input', () {
      expect(parseHebrewGrammar(''), isNull);
      expect(parseHebrewGrammar('bogus'), isNull);
      expect(parseHebrewGrammar('N-bogus'), isNull);
    });
  });
}
