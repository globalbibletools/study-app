import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/changelog/changelog_dialog.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/changelog/changelog_view.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/log_statement.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/fake_messenger_view_model.dart';
import '../fixtures/recording_log_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSettings settings;
  late List<LogStatement> logs;

  Future<void> createSettings([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    settings = UserSettings();
    await settings.init();
    logs.clear();
  }

  Map<String, dynamic> entry(
    String version,
    String date,
    String type,
    List<String> changes,
  ) {
    return {'version': version, 'date': date, 'type': type, 'changes': changes};
  }

  ChangelogService createService(List<Map<String, dynamic>> entries) {
    return ChangelogService.withDependencies(
      settings: settings,
      assetLoader: (path) async {
        if (path == 'assets/l10n/changelog_en.json') {
          return jsonEncode(entries);
        }
        throw Exception('Missing asset: $path');
      },
    );
  }

  ChangelogService createFailingService() {
    return ChangelogService.withDependencies(
      settings: settings,
      assetLoader: (path) async => throw Exception('Missing asset: $path'),
    );
  }

  Widget buildApp(ChangelogService service, {MessengerViewModel? messenger}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _StartupHost(service: service, messenger: messenger),
    );
  }

  setUp(() {
    final writer = RecordingLogWriter();
    logs = writer.statements;
    getIt.registerSingleton<AppLogger>(
      AppLogger(clock: () => DateTime.utc(2026, 11, 27), writers: [writer]),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('fresh install marks the latest version without a dialog', (
    tester,
  ) async {
    await createSettings();
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
    ]);

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsNothing);
    expect(settings.lastSeenChangelogVersion, '1.1.0');
  });

  testWidgets('unseen major entries show the dialog', (tester) async {
    await createSettings({'lastSeenChangelogVersion': '1.0.0'});
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
      entry('2.0.0', '2026-03-01', 'major', ['Third.']),
    ]);

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsOneWidget);
    expect(find.text("What's new"), findsOneWidget);
    expect(
      find.text('See what changed in this version of the app.'),
      findsOneWidget,
    );
    expect(find.text('Read changelog'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(settings.lastSeenChangelogVersion, '1.0.0');
  });

  testWidgets('dismissing the dialog marks the latest version seen', (
    tester,
  ) async {
    await createSettings({'lastSeenChangelogVersion': '1.0.0'});
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('2.0.0', '2026-03-01', 'major', ['Third.']),
    ]);

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsNothing);
    expect(find.byType(ChangelogView), findsNothing);
    expect(settings.lastSeenChangelogVersion, '2.0.0');
  });

  testWidgets('reading the changelog opens the page and marks seen', (
    tester,
  ) async {
    final messenger = FakeMessengerViewModel();
    addTearDown(messenger.dispose);
    await createSettings({'lastSeenChangelogVersion': '1.0.0'});
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('2.0.0', '2026-03-01', 'major', ['Third.']),
    ]);

    await tester.pumpWidget(buildApp(service, messenger: messenger));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read changelog'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsNothing);
    expect(find.byType(ChangelogView), findsOneWidget);
    expect(find.text('2.0.0'), findsOneWidget);
    expect(messenger.messages, isEmpty);
    expect(settings.lastSeenChangelogVersion, '2.0.0');
  });

  testWidgets('unseen minor entries alone do not show the dialog', (
    tester,
  ) async {
    await createSettings({'lastSeenChangelogVersion': '1.0.0'});
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('1.1.0', '2026-02-01', 'minor', ['Second.']),
    ]);

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsNothing);
    expect(settings.lastSeenChangelogVersion, '1.0.0');
  });

  testWidgets('a stored version missing from the file shows no dialog', (
    tester,
  ) async {
    await createSettings({'lastSeenChangelogVersion': '99.0.0'});
    final service = createService([
      entry('1.0.0', '2026-01-01', 'major', ['First.']),
      entry('2.0.0', '2026-03-01', 'major', ['Second.']),
    ]);

    await tester.pumpWidget(buildApp(service));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogDialog), findsNothing);
    expect(settings.lastSeenChangelogVersion, '99.0.0');
  });

  testWidgets('a load failure is logged without crashing or showing a dialog', (
    tester,
  ) async {
    await createSettings({'lastSeenChangelogVersion': '1.0.0'});

    await tester.pumpWidget(buildApp(createFailingService()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ChangelogDialog), findsNothing);
    expect(settings.lastSeenChangelogVersion, '1.0.0');
    expect(
      logs.map((log) => log.message),
      contains('Failed to load changelog on startup'),
    );
  });
}

class _StartupHost extends StatefulWidget {
  const _StartupHost({required this.service, this.messenger});

  final ChangelogService service;
  final MessengerViewModel? messenger;

  @override
  State<_StartupHost> createState() => _StartupHostState();
}

class _StartupHostState extends State<_StartupHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChangelogDialog.showOnStartup(
        context,
        service: widget.service,
        messenger: widget.messenger,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Home'));
  }
}
