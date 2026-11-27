import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = ['en', 'es', 'fr', 'pt', 'ar'];

  List<Map<String, dynamic>> readEntries(String locale) {
    final file = File('assets/l10n/changelog_$locale.json');
    expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<List<dynamic>>());

    return [
      for (final entry in decoded as List<dynamic>)
        entry as Map<String, dynamic>,
    ];
  }

  test('every locale parses and shares the same version sequence', () {
    final english = readEntries('en');
    expect(english, isNotEmpty);

    for (final locale in locales) {
      final entries = readEntries(locale);

      expect(
        entries.map((entry) => entry['version']).toList(),
        english.map((entry) => entry['version']).toList(),
        reason: 'Version sequence differs for $locale',
      );
      expect(
        entries.map((entry) => entry['type']).toList(),
        english.map((entry) => entry['type']).toList(),
        reason: 'Type sequence differs for $locale',
      );
      expect(
        entries.map((entry) => entry['date']).toList(),
        english.map((entry) => entry['date']).toList(),
        reason: 'Date sequence differs for $locale',
      );
    }
  });

  test('every entry is well formed', () {
    for (final locale in locales) {
      for (final entry in readEntries(locale)) {
        expect(entry['version'], isA<String>());
        expect(entry['date'], isA<String>());
        expect(DateTime.tryParse(entry['date'] as String), isNotNull);
        expect(entry['type'], anyOf('major', 'minor'));

        final changes = entry['changes'] as List<dynamic>;
        expect(changes, isNotEmpty);
        for (final change in changes) {
          expect(change, isA<String>());
          expect(change as String, isNotEmpty);
        }
      }
    }
  });

  test('the current pubspec version has a changelog entry', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionLine = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(versionLine, isNotNull);
    final version = versionLine!.group(1)!.split('+').first;

    final versions = readEntries(
      'en',
    ).map((entry) => entry['version']).toList();
    expect(versions, contains(version));
  });
}
