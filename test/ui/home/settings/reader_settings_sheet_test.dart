import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/appbar/appbar.dart';
import 'package:gbt/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/settings/reader_settings_sheet.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';
import 'package:scripture/scripture.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeResourceService implements ResourceService {
  @override
  final outdatedResourceCounts = ValueNotifier<OutdatedResourceCounts>(
    const OutdatedResourceCounts(),
  );

  @override
  Future<List<Resource>> getResourcesByType(
    ResourceType resourceType, {
    bool includeRemoved = true,
    String? langCode,
  }) async {
    if (resourceType == ResourceType.bible) {
      return [
        Resource(id: 'eng_bsb', type: ResourceType.bible, resourceName: 'BSB'),
      ];
    }
    return [
      Resource(id: 'eng', type: ResourceType.gloss, resourceName: 'English'),
    ];
  }

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

class FakeDownloadService implements DownloadService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBibleService implements BibleService {
  @override
  ResourceLanguageTextDirection get currentTextDirection =>
      ResourceLanguageTextDirection.ltr;
  @override
  String? get currentBibleId => 'eng_bsb';
  @override
  void addBibleResourceChangeListener(BibleResourceChangeListener listener) {}
  @override
  void removeBibleResourceChangeListener(
    BibleResourceChangeListener listener,
  ) {}
  @override
  Future<bool> bibleExists(String bibleId) async => true;
  @override
  Future<List<UsfmLine>> getChapter(
    int bookId,
    int chapter, {
    void Function(String bibleId)? onDatabaseMissing,
  }) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReadingSessionViewModel implements ReadingSessionViewModel {
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAppGuideManager implements AppGuideManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserSettings settings;
  late HomeManager homeManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<NavigationViewModel>(NavigationViewModel(settings));
    getIt.registerSingleton<DownloadService>(FakeDownloadService());
    getIt.registerSingleton<ResourceService>(FakeResourceService());
    getIt.registerSingleton<BibleService>(FakeBibleService());
    getIt.registerSingleton<ReadingSessionViewModel>(
      FakeReadingSessionViewModel(),
    );
    getIt.registerSingleton<AppGuideManager>(FakeAppGuideManager());
    getIt.registerSingleton<MessengerViewModel>(MessengerViewModel());

    homeManager = HomeManager();
    getIt.registerSingleton<HomeManager>(homeManager);
  });

  tearDown(() {
    homeManager.dispose();
  });

  Widget appWithOpener(Future<void> Function(BuildContext) opener) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => opener(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      appWithOpener(
        (context) => ReaderSettingsSheet.navigateTo(context, onChanged: () {}),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet renders all reader settings sections', (tester) async {
    await openSheet(tester);

    expect(find.text('Reader Settings'), findsOneWidget);
    expect(find.text('Parallel Bible'), findsOneWidget);
    expect(find.text('Gloss Language'), findsOneWidget);
    expect(find.text('Bible Translation'), findsWidgets);
    expect(find.text('Verse Layout'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
  });

  testWidgets(
    'parallel-Bible toggle turns the panel on and persists when a Bible is '
    'selected',
    (tester) async {
      await settings.setCurrentBible('eng_bsb');
      await openSheet(tester);

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(settings.parallelBibleEnabled, isTrue);
      expect(homeManager.isSinglePanelNotifier.value, isFalse);
    },
  );

  testWidgets(
    'parallel-Bible toggle with no Bible prompts to choose and reverts on '
    'cancel',
    (tester) async {
      // Fresh installs get a Bible from migration; the no-Bible state only
      // arises when the user picks None in the chooser.
      await settings.setCurrentBible(null);
      expect(settings.currentBible, isNull);
      await openSheet(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // The Bible chooser dialog appears above the sheet.
      expect(find.byType(SimpleDialog), findsOneWidget);

      // Cancel the chooser (system back).
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(settings.parallelBibleEnabled, isFalse);
      expect(homeManager.isSinglePanelNotifier.value, isTrue);
    },
  );

  testWidgets('onChanged fires when the sheet closes', (tester) async {
    var changed = 0;
    await tester.pumpWidget(
      appWithOpener(
        (context) => ReaderSettingsSheet.navigateTo(
          context,
          onChanged: () {
            changed++;
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(changed, 0);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(changed, 1);
  });

  testWidgets('appbar gear opens the reader settings sheet', (tester) async {
    await settings.setCurrentBible('eng_bsb');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) => Scaffold(
            appBar: HomeAppBar(
              displayBookId: 1,
              displayChapter: 1,
              displayVerse: 1,
              readingSessionStarted: false,
              onChapterSelected: (bookId, chapter) {},
              onVerseSelected: (verse) {},
              onOpenReaderSettings: () =>
                  ReaderSettingsSheet.navigateTo(context),
              onPlayAudio: () {},
              referenceChooserKey: GlobalKey<ReferenceChooserState>(),
              onInputModeChanged: (mode) {},
              onToggleReadingSession: () {},
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    // The splitscreen panel toggle is gone; the gear is there.
    expect(find.byIcon(Icons.splitscreen), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Reader Settings'), findsOneWidget);
    expect(find.text('Parallel Bible'), findsOneWidget);
  });
}
