import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/parallel_translations_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeResourceService implements ResourceService {
  final List<Resource> bibles;

  FakeResourceService({required this.bibles});

  @override
  Future<List<Resource>> getResourcesByType(
    ResourceType resourceType, {
    bool includeRemoved = true,
    String? langCode,
  }) async => bibles;

  @override
  Future<bool> resourceExists(ResourceType type, String id) async => true;

  @override
  void addResourceChangeListener(
    ResourceType type,
    void Function(ResourceType type, String id) listener,
  ) {}

  @override
  void removeResourceChangeListener(
    ResourceType type,
    void Function(ResourceType type, String id) listener,
  ) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSettings settings;

  final testBibles = [
    Resource(
      id: 'eng_ult',
      type: ResourceType.bible,
      resourceName: 'Unlocked Literal Translation',
      creatorName: 'Door43 World Missions Community',
      installableDetails: const InstallableDetails(
        serverState: ServerState.available,
        serverUpdatedAt: '2023-01-01',
        sha256: 'abc',
        size: 1000,
        url: 'http://example.com',
        installState: InstallState.installed,
      ),
    ),
    Resource(
      id: 'eng_bsb',
      type: ResourceType.bible,
      resourceName: 'Berean Standard Bible',
      creatorName: 'Berean Bible Translation Committee',
      installableDetails: const InstallableDetails(
        serverState: ServerState.available,
        serverUpdatedAt: '2023-01-01',
        sha256: 'def',
        size: 1000,
        url: 'http://example.com',
        installState: InstallState.installed,
      ),
    ),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<ResourceService>(
      FakeResourceService(bibles: testBibles),
    );
  });

  testWidgets('renders available translations and toggles selection', (
    tester,
  ) async {
    bool changed = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: ParallelTranslationsSheet(onChanged: () => changed = true),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Parallel Translations'), findsOneWidget);
    expect(find.text('Unlocked Literal Translation'), findsOneWidget);
    expect(find.text('Berean Standard Bible'), findsOneWidget);

    // Initial state: none selected
    expect(settings.occurrenceParallelBibles, isEmpty);

    // Tap first translation
    await tester.tap(find.text('Unlocked Literal Translation'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
    expect(settings.occurrenceParallelBibles, ['eng_ult']);

    // Tap second translation
    await tester.tap(find.text('Berean Standard Bible'));
    await tester.pumpAndSettle();

    expect(
      settings.occurrenceParallelBibles,
      containsAll(['eng_ult', 'eng_bsb']),
    );

    // Tap first translation again to deselect
    await tester.tap(find.text('Unlocked Literal Translation'));
    await tester.pumpAndSettle();

    expect(settings.occurrenceParallelBibles, ['eng_bsb']);
  });
}
