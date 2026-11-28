import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/release.dart';

void main() {
  group('ReleaseVersion', () {
    final parseCases = <(String, String, bool)>[
      ('26.11.0', '26.11.0', false),
      ('26.11.0-beta3', '26.11.0-beta3', true),
      ('26.11.0-beta10', '26.11.0-beta10', true),
      ('26.01.12', '26.01.12', false),
    ];
    for (final (input, expected, isBeta) in parseCases) {
      test('parses $input', () {
        final version = ReleaseVersion.parse(input);
        expect(version.name, expected);
        expect(version.isBeta, isBeta);
        expect(version.base.name, expected.split('-').first);
      });
    }

    final invalidVersions = [
      '',
      '26.11',
      '26.11.0+44',
      'v26.11.0',
      '26.11.0-beta',
      '26.11.0-beta0',
      '26.11.0-beta01',
      '26.11.0-beta1x',
      '26.11.0-BETA1',
      '26.13.0',
      '26.00.0',
    ];
    for (final input in invalidVersions) {
      test('rejects "$input"', () {
        expect(
          () => ReleaseVersion.parse(input),
          throwsA(isA<ReleaseException>()),
        );
      });
    }

    final comparisonCases = <(String, String, int)>[
      ('26.11.0', '26.11.0-beta3', 1),
      ('26.11.0-beta3', '26.11.0', -1),
      ('26.11.0-beta10', '26.11.0-beta9', 1),
      ('26.11.1-beta1', '26.11.0', 1),
      ('26.12.0', '26.11.99', 1),
      ('26.11.0', '26.11.0', 0),
    ];
    for (final (left, right, expected) in comparisonCases) {
      test('orders $left against $right', () {
        expect(
          ReleaseVersion.parse(left).compareTo(ReleaseVersion.parse(right)),
          expected,
        );
      });
    }
  });

  group('computeNextRelease', () {
    final cases =
        <
          ({
            DateTime date,
            List<String> tags,
            String beta,
            String public,
            bool activeBeta,
          })
        >[
          (
            date: DateTime(2026, 11, 27),
            tags: [
              '26.9.0',
              '26.10.0',
              '26.10.1-beta1',
              '26.10.1-beta2',
              '26.11.0-beta1',
              '26.11.0-beta2',
              '26.11.0-beta3',
            ],
            beta: '26.11.0-beta4',
            public: '26.11.0',
            activeBeta: true,
          ),
          (
            date: DateTime(2026, 12, 15),
            tags: [
              '26.10.0',
              '26.11.0-beta1',
              '26.11.0-beta2',
              '26.11.0-beta3',
            ],
            beta: '26.12.0-beta1',
            public: '26.12.0',
            activeBeta: false,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.0', '26.11.0-beta3'],
            beta: '26.11.1-beta1',
            public: '26.11.1',
            activeBeta: false,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.1', '26.11.2-beta2'],
            beta: '26.11.2-beta3',
            public: '26.11.2',
            activeBeta: true,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.9.0', '26.10.0', '26.10.1-beta2'],
            beta: '26.11.0-beta1',
            public: '26.11.0',
            activeBeta: false,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.4'],
            beta: '26.11.5-beta1',
            public: '26.11.5',
            activeBeta: false,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.3-beta2'],
            beta: '26.11.3-beta3',
            public: '26.11.3',
            activeBeta: true,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.2', '26.11.1-beta9'],
            beta: '26.11.3-beta1',
            public: '26.11.3',
            activeBeta: false,
          ),
          (
            date: DateTime(2026, 11, 27),
            tags: ['26.11.0-beta9', '26.11.0-beta10'],
            beta: '26.11.0-beta11',
            public: '26.11.0',
            activeBeta: true,
          ),
          (
            date: DateTime(2026, 1, 5),
            tags: ['25.12.7'],
            beta: '26.01.0-beta1',
            public: '26.01.0',
            activeBeta: false,
          ),
        ];

    for (final item in cases) {
      test('${formatReleaseDate(item.date)} with ${item.tags.join(', ')}', () {
        final plan = computeNextRelease(date: item.date, tags: item.tags);
        expect(plan.nextBeta.name, item.beta);
        expect(plan.nextPublic.name, item.public);
        expect(plan.activeBeta, item.activeBeta);
        expect(plan.nextFor(ReleaseKind.beta).name, item.beta);
        expect(plan.nextFor(ReleaseKind.public).name, item.public);
      });
    }

    test('ignores historical tags outside the canonical pattern', () {
      final plan = computeNextRelease(
        date: DateTime(2026, 11, 27),
        tags: ['26.9.0', '26.9.3', '26.10.0', '26.11.0-beta3'],
      );
      expect(plan.nextBeta.name, '26.11.0-beta4');
      expect(plan.nextPublic.name, '26.11.0');
    });

    test('current repository state gives beta4 and 26.11.0', () {
      final plan = computeNextRelease(
        date: DateTime(2026, 11, 27),
        tags: ['26.10.0', '26.11.0-beta1', '26.11.0-beta2', '26.11.0-beta3'],
      );
      expect(plan.nextBeta.name, '26.11.0-beta4');
      expect(plan.nextPublic.name, '26.11.0');
      expect(plan.publicBase.name, '26.11.0');
    });

    test('serializes the next plan as JSON', () {
      final plan = computeNextRelease(
        date: DateTime(2026, 11, 27),
        tags: ['26.10.0', '26.11.0-beta3'],
      );
      expect(plan.toJson(ReleaseKind.beta), {
        'kind': 'beta',
        'version': '26.11.0-beta4',
        'date': '2026-11-27',
        'month': '26.11',
        'activeBeta': true,
        'publicBase': '26.11.0',
        'nextBeta': '26.11.0-beta4',
        'nextPublic': '26.11.0',
      });
    });
  });

  group('changelog text', () {
    test('appends without rewriting existing entries', () {
      const source = '''
[
  {
    "version": "26.10.0",
    "date": "2026-10-29",
    "type": "minor",
    "changes": [
      "Existing note"
    ]
  }
]
''';
      final entry = ChangelogEntry(
        version: ReleaseVersion.parse('26.11.0'),
        date: '2026-11-27',
        type: 'major',
        summary: 'A new major release.',
        changes: ['New note'],
      );

      final updated = appendChangelogEntryText(source, entry);
      final entries = parseChangelog(updated, source: 'updated');

      expect(entries, hasLength(2));
      expect(entries.first.version.name, '26.10.0');
      expect(entries.first.changes, ['Existing note']);
      expect(entries.last.toJson(), entry.toJson());
      expect(updated, endsWith(']\n'));
      expect(
        updated,
        startsWith(source.substring(0, source.lastIndexOf(']')).trimRight()),
      );
    });

    test('appends to an empty array', () {
      final entry = ChangelogEntry(
        version: ReleaseVersion.parse('26.11.0'),
        date: '2026-11-27',
        type: 'minor',
        changes: ['First note'],
      );
      final updated = appendChangelogEntryText('[]\n', entry);
      final entries = parseChangelog(updated, source: 'updated');
      expect(entries.single.toJson(), entry.toJson());
      expect(updated, endsWith(']\n'));
    });

    test('appends to a compact array', () {
      const source =
          '[{"version":"26.10.0","date":"2026-10-29",'
          '"type":"minor","changes":["Existing"]}]';
      final entry = ChangelogEntry(
        version: ReleaseVersion.parse('26.11.0'),
        date: '2026-11-27',
        type: 'minor',
        changes: ['New'],
      );
      final updated = appendChangelogEntryText(source, entry);
      expect(updated, startsWith(source.substring(0, source.length - 1)));
      expect(
        parseChangelog(updated, source: 'updated').map((e) => e.version.name),
        ['26.10.0', '26.11.0'],
      );
    });

    final invalidDocuments = <(String, String)>[
      ('not an array', '{"version": "26.11.0"}'),
      (
        'beta version',
        _json([
          _entry('26.11.0-beta1', '2026-11-27', 'minor', ['Note']),
        ]),
      ),
      (
        'bad type',
        _json([
          _entry('26.11.0', '2026-11-27', 'patch', ['Note']),
        ]),
      ),
      (
        'major without summary',
        _json([
          _entry('26.11.0', '2026-11-27', 'major', ['Note']),
        ]),
      ),
      (
        'major with an empty summary',
        _json([
          _entry('26.11.0', '2026-11-27', 'major', ['Note'], summary: '   '),
        ]),
      ),
      (
        'minor with summary',
        _json([
          _entry('26.11.0', '2026-11-27', 'minor', [
            'Note',
          ], summary: 'Summary'),
        ]),
      ),
      (
        'empty changes',
        _json([
          {
            'version': '26.11.0',
            'date': '2026-11-27',
            'type': 'minor',
            'changes': <String>[],
          },
        ]),
      ),
      (
        'bad date',
        _json([
          _entry('26.11.0', '2026-13-01', 'minor', ['Note']),
        ]),
      ),
      (
        'decreasing versions',
        _json([
          _entry('26.11.0', '2026-11-27', 'minor', ['New']),
          _entry('26.10.0', '2026-10-29', 'minor', ['Old']),
        ]),
      ),
      (
        'duplicate versions',
        _json([
          _entry('26.11.0', '2026-11-27', 'minor', ['One']),
          _entry('26.11.0', '2026-11-28', 'minor', ['Two']),
        ]),
      ),
    ];
    for (final (name, content) in invalidDocuments) {
      test('rejects $name', () {
        expect(
          () => parseChangelog(content, source: 'test.json'),
          throwsA(isA<ReleaseException>()),
        );
      });
    }
  });

  group('locales', () {
    test('discovers ARB locales and their changelog files', () {
      final root = _makeWorkspace();
      expect(discoverLocales(root), ['en', 'es']);
    });

    test('rejects a missing changelog file', () {
      final root = _makeWorkspace();
      File('${root.path}/assets/l10n/changelog_es.json').deleteSync();
      expect(
        () => discoverLocales(root),
        throwsA(
          isA<ReleaseException>().having(
            (error) => error.message,
            'message',
            contains('Missing changelog file'),
          ),
        ),
      );
    });

    test('rejects a changelog file without an ARB locale', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'fr', [_entry26_10_0('fr')]);
      expect(
        () => discoverLocales(root),
        throwsA(
          isA<ReleaseException>().having(
            (error) => error.message,
            'message',
            contains('without a matching app locale'),
          ),
        ),
      );
    });

    test('rejects locale sequences that differ in version', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'es', [
        _entry('26.9.9', '2026-10-01', 'minor', ['x']),
      ]);
      expect(() => ChangelogSet.load(root), throwsA(isA<ReleaseException>()));
    });

    test('rejects locale sequences that differ in type or date', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'es', [
        _entry('26.10.0', '2026-10-29', 'major', [
          'Nota existente',
        ], summary: 'Resumen existente'),
      ]);
      expect(() => ChangelogSet.load(root), throwsA(isA<ReleaseException>()));
    });

    test('rejects locale sequences with different lengths', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'es', [
        _entry('26.10.0', '2026-10-29', 'minor', ['Nota existente']),
        _entry('26.11.0', '2026-11-27', 'minor', ['Otra nota']),
      ]);
      expect(() => ChangelogSet.load(root), throwsA(isA<ReleaseException>()));
    });
  });

  group('planChangelogAppend', () {
    test('requires every app locale in the input', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['Only English'],
          },
        }),
        source: 'input',
      );
      expect(
        () => planChangelogAppend(
          set,
          version: ReleaseVersion.parse('26.11.0'),
          date: DateTime(2026, 11, 27),
          input: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects locales without an app locale', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['English'],
            'es': ['Español'],
            'fr': ['Français'],
          },
        }),
        source: 'input',
      );
      expect(
        () => planChangelogAppend(
          set,
          version: ReleaseVersion.parse('26.11.0'),
          date: DateTime(2026, 11, 27),
          input: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a version that is not newer than the last entry', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['Old'],
            'es': ['Viejo'],
          },
        }),
        source: 'input',
      );
      expect(
        () => planChangelogAppend(
          set,
          version: ReleaseVersion.parse('26.9.0'),
          date: DateTime(2026, 9, 1),
          input: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('refuses to rewrite an existing entry for the same version', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['Different'],
            'es': ['Diferente'],
          },
        }),
        source: 'input',
      );
      expect(
        () => planChangelogAppend(
          set,
          version: ReleaseVersion.parse('26.10.0'),
          date: DateTime(2026, 10, 29),
          input: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('treats an identical existing entry as already applied', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['Existing note'],
            'es': ['Nota existente'],
          },
        }),
        source: 'input',
      );
      final writes = planChangelogAppend(
        set,
        version: ReleaseVersion.parse('26.10.0'),
        date: DateTime(2026, 10, 29),
        input: input,
      );
      expect(writes, hasLength(2));
      expect(writes.every((write) => !write.changed), isTrue);
    });

    test('rejects beta versions', () {
      final root = _makeWorkspace();
      final set = ChangelogSet.load(root);
      final input = ChangelogInput.parse(
        _json({
          'type': 'minor',
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        source: 'input',
      );
      expect(
        () => planChangelogAppend(
          set,
          version: ReleaseVersion.parse('26.11.0-beta4'),
          date: DateTime(2026, 11, 27),
          input: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('requires a summary for major entries and forbids one for minor', () {
      final parsed = ChangelogInput.parse(
        _json({
          'type': 'major',
          'summary': {'en': 'Summary', 'es': 'Resumen'},
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        source: 'input',
      );
      expect(parsed.summary, {'en': 'Summary', 'es': 'Resumen'});

      for (final input in [
        _json({
          'type': 'major',
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        _json({
          'type': 'minor',
          'summary': {'en': 'Summary', 'es': 'Resumen'},
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        _json({
          'type': 'major',
          'summary': {'en': 'Summary'},
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        _json({
          'type': 'major',
          'summary': {'en': 'Summary', 'es': 'Resumen', 'fr': 'Résumé'},
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
        _json({
          'type': 'major',
          'summary': {'en': 'Summary', 'es': '   '},
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
      ]) {
        expect(
          () => ChangelogInput.parse(input, source: 'input'),
          throwsA(isA<ReleaseException>()),
        );
      }
    });

    test('rejects duplicated or unknown input keys', () {
      for (final input in [
        _json({
          'type': 'minor',
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
          'version': '26.11.0',
        }),
        _json({
          'type': 'minor',
          'changes': {
            'en': ['English'],
            'es': <String>[],
          },
        }),
        _json({
          'type': 'patch',
          'changes': {
            'en': ['English'],
            'es': ['Español'],
          },
        }),
      ]) {
        expect(
          () => ChangelogInput.parse(input, source: 'input'),
          throwsA(isA<ReleaseException>()),
        );
      }
    });
  });

  group('prepareRelease', () {
    const tags = ['26.10.0', '26.11.0-beta1', '26.11.0-beta3'];

    test('prepares a public release with localized changelog notes', () {
      final root = _makeWorkspace();
      final input = _writeInput(
        root,
        type: 'major',
        summary: {
          'en': 'Introducing the new release.',
          'es': 'Presentamos la nueva versión.',
        },
        changes: {
          'en': ['New note', 'Another note'],
          'es': ['Nota nueva', 'Otra nota'],
        },
      );

      final result = _prepare(
        root,
        kind: ReleaseKind.public,
        version: '26.11.0',
        tags: tags,
        changelogPath: input,
      );

      expect(result.version.name, '26.11.0');
      expect(result.changelogLocales, ['en', 'es']);
      expect(result.updatedFiles, contains('pubspec.yaml'));
      expect(result.updatedFiles, contains('assets/l10n/changelog_en.json'));
      expect(result.updatedFiles, contains('assets/l10n/changelog_es.json'));

      final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('version: 26.11.0\n'));
      expect(pubspec, isNot(contains('+')));

      final en = _readChangelog(root, 'en');
      expect(en.last['version'], '26.11.0');
      expect(en.last['date'], '2026-11-27');
      expect(en.last['type'], 'major');
      expect(en.last['summary'], 'Introducing the new release.');
      expect(en.last['changes'], ['New note', 'Another note']);
      expect(en.first['version'], '26.10.0');

      final es = _readChangelog(root, 'es');
      expect(es.last['summary'], 'Presentamos la nueva versión.');
      expect(es.last['changes'], ['Nota nueva', 'Otra nota']);
    });

    test('detects a changed summary on an already prepared release', () {
      final root = _makeWorkspace();
      final input = _writeInput(
        root,
        type: 'major',
        summary: {'en': 'First summary.', 'es': 'Primer resumen.'},
        changes: {
          'en': ['New note'],
          'es': ['Nota nueva'],
        },
      );
      _prepare(
        root,
        kind: ReleaseKind.public,
        version: '26.11.0',
        tags: tags,
        changelogPath: input,
      );

      _writeInput(
        root,
        type: 'major',
        summary: {'en': 'Different summary.', 'es': 'Resumen diferente.'},
        changes: {
          'en': ['New note'],
          'es': ['Nota nueva'],
        },
      );
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.public,
          version: '26.11.0',
          tags: tags,
          changelogPath: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('is idempotent for an identical prepared release', () {
      final root = _makeWorkspace();
      final input = _writeInput(
        root,
        changes: {
          'en': ['New note'],
          'es': ['Nota nueva'],
        },
      );
      _prepare(
        root,
        kind: ReleaseKind.public,
        version: '26.11.0',
        tags: tags,
        changelogPath: input,
      );
      final before = File(
        '${root.path}/assets/l10n/changelog_en.json',
      ).readAsStringSync();

      final result = _prepare(
        root,
        kind: ReleaseKind.public,
        version: '26.11.0',
        tags: tags,
        changelogPath: input,
      );

      expect(result.updatedFiles, isEmpty);
      expect(
        File('${root.path}/assets/l10n/changelog_en.json').readAsStringSync(),
        before,
      );
      expect(_readChangelog(root, 'en'), hasLength(2));
    });

    test('prepares a public release without a changelog entry', () {
      final root = _makeWorkspace();
      final before = File(
        '${root.path}/assets/l10n/changelog_en.json',
      ).readAsStringSync();

      final result = _prepare(
        root,
        kind: ReleaseKind.public,
        version: '26.11.0',
        tags: tags,
        noChangelog: true,
      );

      expect(result.changelogLocales, isEmpty);
      expect(result.updatedFiles, ['pubspec.yaml']);
      expect(_readPubspec(root), '26.11.0');
      expect(
        File('${root.path}/assets/l10n/changelog_en.json').readAsStringSync(),
        before,
      );
    });

    test('prepares a beta release without touching the changelog', () {
      final root = _makeWorkspace();
      final before = File(
        '${root.path}/assets/l10n/changelog_en.json',
      ).readAsStringSync();

      final result = _prepare(
        root,
        kind: ReleaseKind.beta,
        version: '26.11.0-beta4',
        tags: tags,
      );

      expect(result.changelogLocales, isEmpty);
      expect(_readPubspec(root), '26.11.0-beta4');
      expect(
        File('${root.path}/assets/l10n/changelog_en.json').readAsStringSync(),
        before,
      );
    });

    test('rejects a changelog on a beta release', () {
      final root = _makeWorkspace();
      final input = _writeInput(root);
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.beta,
          version: '26.11.0-beta4',
          tags: tags,
          changelogPath: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('requires an explicit changelog decision for public releases', () {
      final root = _makeWorkspace();
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.public,
          version: '26.11.0',
          tags: tags,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a version that is not next for the current month', () {
      final root = _makeWorkspace();
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.public,
          version: '26.12.0',
          tags: tags,
          noChangelog: true,
        ),
        throwsA(
          isA<ReleaseException>().having(
            (error) => error.message,
            'message',
            contains('expected 26.11.0'),
          ),
        ),
      );
    });

    test('rejects a beta once the same base is public', () {
      final root = _makeWorkspace();
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.beta,
          version: '26.11.0-beta1',
          tags: ['26.11.0'],
        ),
        throwsA(
          isA<ReleaseException>().having(
            (error) => error.message,
            'message',
            contains('expected 26.11.1-beta1'),
          ),
        ),
      );
    });

    test('rejects build metadata', () {
      final root = _makeWorkspace();
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.beta,
          version: '26.11.0-beta4+44',
          tags: tags,
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('validates the changelog before writing pubspec.yaml', () {
      final root = _makeWorkspace();
      final input = _writeInput(
        root,
        changes: {
          'en': ['Only English'],
        },
      );
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.public,
          version: '26.11.0',
          tags: tags,
          changelogPath: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
      expect(_readPubspec(root), '26.10.0');
    });

    test('refuses a changelog version older than the last entry', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'en', [
        _entry('26.12.0', '2026-12-01', 'minor', ['Future']),
      ]);
      _writeChangelog(root, 'es', [
        _entry('26.12.0', '2026-12-01', 'minor', ['Futuro']),
      ]);
      final input = _writeInput(root);
      expect(
        () => _prepare(
          root,
          kind: ReleaseKind.public,
          version: '26.11.0',
          tags: tags,
          changelogPath: input,
        ),
        throwsA(isA<ReleaseException>()),
      );
      expect(_readPubspec(root), '26.10.0');
    });
  });

  group('verifyRelease', () {
    test('accepts a public tag with matching pubspec and changelog', () {
      final root = _makeWorkspace();
      final result = verifyRelease(
        root: root,
        tag: '26.10.0',
        localTags: ['26.9.3'],
        remoteTags: const [],
      );
      expect(result.version.name, '26.10.0');
      expect(result.locales, ['en', 'es']);
    });

    test('accepts a public release without a changelog entry', () {
      final root = _makeWorkspace(pubspecVersion: '26.11.0');
      final result = verifyRelease(
        root: root,
        tag: '26.11.0',
        localTags: ['26.10.0'],
        remoteTags: const [],
      );
      expect(result.pubspecVersion.name, '26.11.0');
    });

    test('accepts a beta tag', () {
      final root = _makeWorkspace(pubspecVersion: '26.11.0-beta4');
      final result = verifyRelease(
        root: root,
        tag: '26.11.0-beta4',
        localTags: ['26.11.0-beta3'],
        remoteTags: const [],
      );
      expect(result.version.isBeta, isTrue);
    });

    test('rejects a tag that already exists locally', () {
      final root = _makeWorkspace();
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.10.0',
          localTags: ['26.10.0'],
          remoteTags: const [],
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a tag that already exists remotely', () {
      final root = _makeWorkspace();
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.10.0',
          localTags: const [],
          remoteTags: ['26.10.0'],
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a tag that is not newer than existing tags', () {
      final root = _makeWorkspace(pubspecVersion: '26.9.3');
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.9.3',
          localTags: ['26.10.0'],
          remoteTags: const [],
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a pubspec version mismatch', () {
      final root = _makeWorkspace();
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.11.0',
          localTags: ['26.10.0'],
          remoteTags: const [],
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects a pubspec version with a build number', () {
      final root = _makeWorkspace(pubspecVersion: '26.10.0+44');
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.10.0',
          localTags: const [],
          remoteTags: const [],
        ),
        throwsA(
          isA<ReleaseException>().having(
            (error) => error.message,
            'message',
            contains('build number'),
          ),
        ),
      );
    });

    test('rejects an invalid tag', () {
      final root = _makeWorkspace();
      expect(
        () => verifyRelease(
          root: root,
          tag: 'v26.10.0',
          localTags: const [],
          remoteTags: const [],
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('rejects inconsistent locale changelogs', () {
      final root = _makeWorkspace();
      _writeChangelog(root, 'es', [
        _entry('26.10.0', '2026-10-29', 'major', [
          'Nota existente',
        ], summary: 'Resumen existente'),
      ]);
      expect(
        () => verifyRelease(
          root: root,
          tag: '26.11.0',
          localTags: ['26.10.0'],
          remoteTags: const [],
          pubspecContent: 'name: test\nversion: 26.11.0\n',
        ),
        throwsA(isA<ReleaseException>()),
      );
    });
  });
}

Directory _makeWorkspace({String pubspecVersion = '26.10.0'}) {
  final root = Directory.systemTemp.createTempSync('gbt_release_test_');
  addTearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });
  _write(root, 'pubspec.yaml', 'name: test\nversion: $pubspecVersion\n');
  _write(root, 'lib/l10n/app_en.arb', '{}\n');
  _write(root, 'lib/l10n/app_es.arb', '{}\n');
  _writeChangelog(root, 'en', [_entry26_10_0('en')]);
  _writeChangelog(root, 'es', [_entry26_10_0('es')]);
  return root;
}

Map<String, Object?> _entry26_10_0(String locale) => _entry(
  '26.10.0',
  '2026-10-29',
  'minor',
  [locale == 'en' ? 'Existing note' : 'Nota existente'],
);

Map<String, Object?> _entry(
  String version,
  String date,
  String type,
  List<String> changes, {
  String? summary,
}) => {
  'version': version,
  'date': date,
  'type': type,
  'summary': ?summary,
  'changes': changes,
};

String _json(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';

void _write(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void _writeChangelog(
  Directory root,
  String locale,
  List<Map<String, Object?>> entries,
) {
  _write(root, 'assets/l10n/changelog_$locale.json', _json(entries));
}

List<Map<String, dynamic>> _readChangelog(Directory root, String locale) {
  final decoded = jsonDecode(
    File('${root.path}/assets/l10n/changelog_$locale.json').readAsStringSync(),
  );
  return [
    for (final entry in decoded as List<dynamic>) entry as Map<String, dynamic>,
  ];
}

String _readPubspec(Directory root) => readPubspecVersion(
  File('${root.path}/pubspec.yaml').readAsStringSync(),
).name;

String _writeInput(
  Directory root, {
  String type = 'minor',
  Map<String, List<String>> changes = const {
    'en': ['New note'],
    'es': ['Nota nueva'],
  },
  Map<String, String>? summary,
}) {
  _write(
    root,
    'release-notes.json',
    _json({'type': type, 'summary': ?summary, 'changes': changes}),
  );
  return '${root.path}/release-notes.json';
}

PrepareResult _prepare(
  Directory root, {
  required ReleaseKind kind,
  required String version,
  required List<String> tags,
  String? changelogPath,
  bool noChangelog = false,
}) {
  return prepareRelease(
    root: root,
    kind: kind,
    version: version,
    date: DateTime(2026, 11, 27),
    changelogPath: changelogPath,
    noChangelog: noChangelog,
    tags: tags,
  );
}
