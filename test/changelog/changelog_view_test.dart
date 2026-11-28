import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/changelog/changelog_view.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/l10n/localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/fake_messenger_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = UserSettings();
    await settings.init();

    final entries = [
      {
        'version': '1.0.0',
        'date': '2026-01-01',
        'type': 'major',
        'summary': 'Major summary.',
        'changes': ['First change.'],
      },
      {
        'version': '1.1.0',
        'date': '2026-02-01',
        'type': 'minor',
        'changes': ['Second change.', 'Third change.'],
      },
    ];

    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<ChangelogService>(
      ChangelogService(
        assetLoader: (path) async {
          if (path == 'assets/l10n/changelog_en.json') {
            return jsonEncode(entries);
          }
          throw Exception('Missing asset: $path');
        },
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }

  testWidgets('renders newest first with accessible semantics', (tester) async {
    final handle = tester.ensureSemantics();
    final service = getIt<ChangelogService>();
    final entries = await service.loadEntries(const Locale('en'));
    expect(settings.lastSeenChangelogVersion, isNull);

    await tester.pumpWidget(buildApp(ChangelogView(entries: entries)));
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('1.1.0')).dy;
    final oldest = tester.getTopLeft(find.text('1.0.0')).dy;
    expect(newest, lessThan(oldest));
    expect(find.text('February 1, 2026'), findsOneWidget);
    expect(find.text('Second change.'), findsOneWidget);
    expect(find.text('Major summary.'), findsOneWidget);
    expect(settings.lastSeenChangelogVersion, '1.1.0');

    final majorCard = find.byKey(const ValueKey('changelog-1.0.0'));
    final minorCard = find.byKey(const ValueKey('changelog-1.1.0'));
    expect(
      find.descendant(of: majorCard, matching: find.text('Major summary.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: minorCard, matching: find.text('Major summary.')),
      findsNothing,
    );

    expect(
      find.semantics.byPredicate(
        (node) =>
            node.label == '1.1.0, February 1, 2026' &&
            node.flagsCollection.isHeader,
      ),
      findsOne,
    );
    expect(find.semantics.byLabel('Second change.'), findsOne);
    expect(find.semantics.byLabel('Major summary.'), findsOne);

    final lists = find.semantics.byPredicate(
      (node) => node.role == SemanticsRole.list,
    );
    final listItems = find.semantics.byPredicate(
      (node) => node.role == SemanticsRole.listItem,
    );
    expect(lists, findsNWidgets(2));
    expect(listItems, findsNWidgets(3));

    handle.dispose();
  });

  testWidgets('navigateTo opens the changelog after loading', (tester) async {
    final messenger = FakeMessengerViewModel();
    addTearDown(messenger.dispose);
    getIt.registerSingleton<MessengerViewModel>(messenger);

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ChangelogView.navigateTo(context),
                  child: const Text('Open changelog'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open changelog'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogView), findsOneWidget);
    expect(find.text('1.1.0'), findsOneWidget);
    expect(messenger.messages, isEmpty);
    expect(settings.lastSeenChangelogVersion, '1.1.0');
  });

  testWidgets('navigateTo reports load errors without opening the page', (
    tester,
  ) async {
    final messenger = FakeMessengerViewModel();
    addTearDown(messenger.dispose);
    final failingService = ChangelogService(
      assetLoader: (path) async => throw Exception('Missing asset: $path'),
    );
    getIt.unregister<ChangelogService>();
    getIt.registerSingleton<ChangelogService>(failingService);
    getIt.registerSingleton<MessengerViewModel>(messenger);

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ChangelogView.navigateTo(context),
                  child: const Text('Open changelog'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open changelog'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogView), findsNothing);
    final l10n = AppLocalizations.of(
      tester.element(find.text('Open changelog')),
    )!;
    expect(messenger.messages.single.text, l10n.errorLoadingContent);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });
}
