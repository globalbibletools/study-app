import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/services/hebrew_greek/srgnt_grammar.dart';

void main() {
  group('parseSrgntGrammar', () {
    test('expands a noun', () {
      expect(parseSrgntGrammar('N....NFS'), 'noun: nominative feminine singular');
    });

    test('expands a finite verb', () {
      expect(
        parseSrgntGrammar('VIAA3..S'),
        'verb: aorist indicative active third-person singular',
      );
    });

    test('expands a participle', () {
      expect(
        parseSrgntGrammar('VPAA.NMS'),
        'verb: aorist participle active nominative masculine singular',
      );
    });

    test('expands a pronoun with a person', () {
      expect(
        parseSrgntGrammar('R...3AMS'),
        'pronoun: third-person accusative masculine singular',
      );
    });

    test('expands an article', () {
      expect(parseSrgntGrammar('E....GNS'), 'article: genitive neuter singular');
    });

    test('expands an infinitive', () {
      expect(parseSrgntGrammar('VNAA....'), 'verb: aorist infinitive active');
    });

    test('expands a word with no descriptors', () {
      expect(parseSrgntGrammar('C.......'), 'conjunction');
    });

    test('treats the anomalous U tense as future', () {
      expect(
        parseSrgntGrammar('VIUA3..P'),
        'verb: future indicative active third-person plural',
      );
    });

    test('handles a pronoun with no gender', () {
      expect(
        parseSrgntGrammar('R...1A.P'),
        'pronoun: first-person accusative plural',
      );
    });

    test('returns null for a Hebrew code', () {
      expect(parseSrgntGrammar('N-cs'), isNull);
      expect(parseSrgntGrammar('V-Qal-Perf-3ms'), isNull);
      expect(parseSrgntGrammar('Conj-w'), isNull);
    });

    test('returns null for the legacy JSON Greek format', () {
      expect(parseSrgntGrammar('N-NFS'), isNull);
      expect(parseSrgntGrammar('V-AIA-1P'), isNull);
    });

    test('returns null for malformed input', () {
      expect(parseSrgntGrammar(''), isNull);
      expect(parseSrgntGrammar('N....NF'), isNull);
      expect(parseSrgntGrammar('X....NFS'), isNull);
      expect(parseSrgntGrammar('N....NFSX'), isNull);
    });
  });
}
