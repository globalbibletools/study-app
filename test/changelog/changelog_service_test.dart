import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/changelog/changelog_entry.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/recording_log_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> assets;
  late List<String> requestedPaths;
  late UserSettings settings;
  late List<LogStatement> logs;

  Future<String> loadAsset(String path) async {
    requestedPaths.add(path);
    final value = assets[path];
    if (value == null) throw Exception('Missing asset: $path');
    return value;
  }

  Future<void> createSettings([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    logs.clear();
  }

  ChangelogService createService() {
    return ChangelogService(assetLoader: loadAsset);
  }

  Map<String, dynamic> entry(
    String version,
    String date,
    String type,
    List<String> changes, {
    String? summary,
  }) {
    return {
      'version': version,
      'date': date,
      'type': type,
      if (type == 'major') 'summary': summary ?? 'Summary for $version.',
      'changes': changes,
    };
  }

  String assetFor(List<Map<String, dynamic>> entries) {
    return jsonEncode(entries);
  }

  setUp(() {
    assets = {};
    requestedPaths = [];
    final writer = RecordingLogWriter();
    logs = writer.statements;
    getIt.registerSingleton<AppLogger>(
      AppLogger(clock: () => DateTime.utc(2026, 11, 27), writers: [writer]),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('seen version', () {
    test('loading does not write the seen version on fresh install', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
        entry('1.2.0', '2026-03-01', 'minor', ['Third.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('en'));

      expect(entries, hasLength(3));
      expect(settings.lastSeenChangelogVersion, isNull);
      expect(service.unseenEntries(entries), isEmpty);
      expect(service.hasUnseenMajor(entries), isFalse);
    });

    test('entries after the stored version are unseen', () async {
      await createSettings({'lastSeenChangelogVersion': '1.0.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
        entry('1.2.0', '2026-03-01', 'minor', ['Third.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('en'));

      expect(service.unseenEntries(entries).map((e) => e.version), [
        '1.1.0',
        '1.2.0',
      ]);
      expect(service.hasUnseenMajor(entries), isFalse);
      expect(settings.lastSeenChangelogVersion, '1.0.0');
    });

    test('an unseen major entry is reported', () async {
      await createSettings({'lastSeenChangelogVersion': '1.0.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
        entry('2.0.0', '2026-03-01', 'major', ['Third.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('en'));

      expect(service.hasUnseenMajor(entries), isTrue);
    });

    test(
      'markLatestSeen advances the stored version to the last entry',
      () async {
        await createSettings({'lastSeenChangelogVersion': '1.0.0'});
        assets['assets/l10n/changelog_en.json'] = assetFor([
          entry('1.0.0', '2026-01-01', 'major', ['First.']),
          entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
          entry('1.2.0', '2026-03-01', 'minor', ['Third.']),
        ]);

        final service = createService();
        final entries = await service.loadEntries(const Locale('en'));
        await service.markLatestSeen();

        expect(settings.lastSeenChangelogVersion, '1.2.0');
        expect(service.unseenEntries(entries), isEmpty);
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.info);
        expect(logs.single.message, 'Set latest changelog version to 1.2.0');
      },
    );

    test('markLatestSeen leaves the current version unchanged', () async {
      await createSettings({'lastSeenChangelogVersion': '1.2.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
        entry('1.2.0', '2026-03-01', 'minor', ['Third.']),
      ]);

      final service = createService();
      await service.loadEntries(const Locale('en'));
      await service.markLatestSeen();

      expect(settings.lastSeenChangelogVersion, '1.2.0');
      expect(logs, isEmpty);
    });

    test('an unknown stored version reports nothing unseen', () async {
      await createSettings({'lastSeenChangelogVersion': '99.0.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('en'));

      expect(service.unseenEntries(entries), isEmpty);
      expect(service.hasUnseenMajor(entries), isFalse);
    });
  });

  group('latestUnseenMajor', () {
    test('fresh install marks the latest version and returns null', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
      ]);

      final service = createService();

      expect(await service.latestUnseenMajor(const Locale('en')), isNull);
      expect(settings.lastSeenChangelogVersion, '1.1.0');
    });

    test('returns null when no unseen entry is major', () async {
      await createSettings({'lastSeenChangelogVersion': '1.0.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
        entry('1.2.0', '2026-03-01', 'minor', ['Third.']),
      ]);

      final service = createService();

      expect(await service.latestUnseenMajor(const Locale('en')), isNull);
      expect(settings.lastSeenChangelogVersion, '1.0.0');
    });

    test('returns the newest unseen major entry', () async {
      await createSettings({'lastSeenChangelogVersion': '1.0.0'});
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['First.']),
        entry('2.0.0', '2026-02-01', 'major', ['Second.']),
        entry('2.1.0', '2026-03-01', 'minor', ['Third.']),
        entry('3.0.0', '2026-04-01', 'major', ['Fourth.']),
        entry('3.1.0', '2026-05-01', 'minor', ['Fifth.']),
      ]);

      final service = createService();
      final latest = await service.latestUnseenMajor(const Locale('en'));

      expect(latest?.version, '3.0.0');
      expect(latest?.summary, 'Summary for 3.0.0.');
      expect(settings.lastSeenChangelogVersion, '1.0.0');
    });
  });

  group('locale loading', () {
    test('loads the locale file when it exists', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['English.']),
      ]);
      assets['assets/l10n/changelog_es.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['Español.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('es'));

      expect(entries.single.changes, ['Español.']);
      expect(requestedPaths, ['assets/l10n/changelog_es.json']);
    });

    test('falls back to English when the locale file is missing', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['English.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('es'));

      expect(entries.single.changes, ['English.']);
      expect(requestedPaths, [
        'assets/l10n/changelog_es.json',
        'assets/l10n/changelog_en.json',
      ]);
      expect(logs, hasLength(1));
      expect(logs.single.level, LogLevel.warning);
      expect(
        logs.single.message,
        'Missing changelog asset for es. Falling back to English',
      );
    });

    test('reports when the English fallback is also missing', () async {
      await createSettings();
      final service = createService();

      await expectLater(
        service.loadEntries(const Locale('es')),
        throwsStateError,
      );

      expect(logs.map((log) => log.level), [LogLevel.warning, LogLevel.error]);
      expect(logs.map((log) => log.message), [
        'Missing changelog asset for es. Falling back to English',
        'Missing English fallback changelog asset for es.',
      ]);
    });

    test('parses the entry fields', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.2.3', '2026-05-06', 'major', ['One.', 'Two.']),
      ]);

      final service = createService();
      final entries = await service.loadEntries(const Locale('en'));
      final parsed = entries.single;

      expect(parsed.version, '1.2.3');
      expect(parsed.date, DateTime(2026, 5, 6));
      expect(parsed.type, ChangelogEntryType.major);
      expect(parsed.summary, 'Summary for 1.2.3.');
      expect(parsed.changes, ['One.', 'Two.']);
    });
  });

  group('cache', () {
    test('reuses the cached entries for the active locale', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['English.']),
      ]);

      final service = createService();
      final first = await service.loadEntries(const Locale('en'));
      final second = await service.loadEntries(const Locale('en'));

      expect(identical(first, second), isTrue);
      expect(requestedPaths, ['assets/l10n/changelog_en.json']);
    });

    test('caches an in-flight load', () async {
      await createSettings();
      final completer = Completer<String>();
      final service = ChangelogService(
        assetLoader: (path) {
          requestedPaths.add(path);
          return completer.future;
        },
      );

      final first = service.loadEntries(const Locale('en'));
      final second = service.loadEntries(const Locale('en'));

      expect(identical(first, second), isTrue);

      completer.complete(
        assetFor([
          entry('1.0.0', '2026-01-01', 'major', ['English.']),
        ]),
      );
      expect((await first).single.version, '1.0.0');
      expect(requestedPaths, ['assets/l10n/changelog_en.json']);
    });

    test('replaces the cache when the locale changes', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['English.']),
      ]);
      assets['assets/l10n/changelog_es.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['Español.']),
      ]);

      final service = createService();
      final firstEnglish = await service.loadEntries(const Locale('en'));
      final spanish = await service.loadEntries(const Locale('es'));
      final secondEnglish = await service.loadEntries(const Locale('en'));

      expect(firstEnglish.single.changes, ['English.']);
      expect(spanish.single.changes, ['Español.']);
      expect(secondEnglish.single.changes, ['English.']);
      expect(identical(firstEnglish, secondEnglish), isFalse);
      expect(requestedPaths, [
        'assets/l10n/changelog_en.json',
        'assets/l10n/changelog_es.json',
        'assets/l10n/changelog_en.json',
      ]);
    });

    test('a superseded failed load does not clear the new cache', () async {
      await createSettings();
      final englishCompleter = Completer<String>();
      final spanishCompleter = Completer<String>();
      final service = ChangelogService(
        assetLoader: (path) {
          requestedPaths.add(path);
          return path.endsWith('changelog_es.json')
              ? spanishCompleter.future
              : englishCompleter.future;
        },
      );

      final english = service.loadEntries(const Locale('en'));
      final englishExpectation = expectLater(english, throwsStateError);
      final spanish = service.loadEntries(const Locale('es'));

      spanishCompleter.complete(
        assetFor([
          entry('1.0.0', '2026-01-01', 'major', ['Español.']),
        ]),
      );
      await spanish;

      englishCompleter.completeError(Exception('English failed'));
      await englishExpectation;

      final cachedSpanish = await service.loadEntries(const Locale('es'));

      expect(cachedSpanish.single.changes, ['Español.']);
      expect(requestedPaths, [
        'assets/l10n/changelog_en.json',
        'assets/l10n/changelog_es.json',
        'assets/l10n/changelog_en.json',
      ]);
    });

    test('does not cache failed loads', () async {
      await createSettings();
      assets['assets/l10n/changelog_en.json'] = 'not json';
      final service = createService();

      await expectLater(
        service.loadEntries(const Locale('en')),
        throwsFormatException,
      );

      assets['assets/l10n/changelog_en.json'] = assetFor([
        entry('1.0.0', '2026-01-01', 'major', ['English.']),
      ]);
      final entries = await service.loadEntries(const Locale('en'));

      expect(entries.single.changes, ['English.']);
      expect(requestedPaths, [
        'assets/l10n/changelog_en.json',
        'assets/l10n/changelog_en.json',
      ]);
      expect(logs, hasLength(1));
      expect(logs.single.level, LogLevel.error);
      expect(logs.single.message, 'Changelog file for en is invalid');
      expect(logs.single.error, isNotNull);
      expect(logs.single.stackTrace, isNotNull);
    });
  });

  group('invalid data', () {
    test('rejects non-array files and non-object entries', () async {
      await createSettings();
      final service = createService();

      for (final payload in <Object>[
        {'version': '1.0.0'},
        ['not an object'],
      ]) {
        assets['assets/l10n/changelog_en.json'] = jsonEncode(payload);
        await expectLater(
          service.loadEntries(const Locale('en')),
          throwsFormatException,
          reason: 'Expected $payload to be rejected',
        );
      }

      expect(logs, hasLength(2));
      expect(logs.map((log) => log.level), everyElement(LogLevel.error));
      expect(
        logs.map((log) => log.message),
        everyElement('Changelog file for en is invalid'),
      );
    });

    test('rejects entries whose fields have the wrong types', () async {
      await createSettings();
      final service = createService();
      final valid = entry('1.0.0', '2026-01-01', 'major', ['Change.']);

      final invalidEntries = <Map<String, dynamic>>[
        {...valid, 'version': 1},
        {...valid, 'date': 20260101},
        {...valid, 'date': 'not a date'},
        {...valid, 'type': 1},
        {...valid, 'type': 'patch'},
        ({...valid}..remove('summary')),
        {...valid, 'summary': null},
        {...valid, 'summary': ''},
        {...valid, 'summary': '   '},
        {...valid, 'summary': 1},
        {...valid, 'type': 'minor'},
        {...valid, 'changes': 'not a list'},
        {
          ...valid,
          'changes': [1],
        },
      ];

      for (final invalidEntry in invalidEntries) {
        assets['assets/l10n/changelog_en.json'] = jsonEncode([invalidEntry]);
        await expectLater(
          service.loadEntries(const Locale('en')),
          throwsFormatException,
          reason: 'Expected $invalidEntry to be rejected',
        );
      }

      expect(logs, hasLength(invalidEntries.length));
      expect(logs.map((log) => log.level), everyElement(LogLevel.error));
      expect(
        logs.map((log) => log.message),
        everyElement('Changelog file for en is invalid'),
      );
    });

    test(
      'does not fall back to English when the locale file is malformed',
      () async {
        await createSettings();
        assets['assets/l10n/changelog_en.json'] = assetFor([
          entry('1.0.0', '2026-01-01', 'major', ['English.']),
        ]);
        assets['assets/l10n/changelog_es.json'] = 'not json';

        final service = createService();

        await expectLater(
          service.loadEntries(const Locale('es')),
          throwsFormatException,
        );
        expect(requestedPaths, ['assets/l10n/changelog_es.json']);
        expect(logs, hasLength(1));
        expect(logs.single.level, LogLevel.error);
        expect(logs.single.message, 'Changelog file for es is invalid');
      },
    );
  });
}
