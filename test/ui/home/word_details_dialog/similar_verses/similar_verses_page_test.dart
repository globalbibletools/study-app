import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/verse_list_item.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
import 'package:scripture/scripture.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHebrewGreekDatabase implements HebrewGreekDatabase {
  @override
  Future<String?> strongsCodeRoot(String strongsCode) async => 'דּוֹד';

  @override
  Future<List<Reference>> allVersesForStrongsCode(String strongsCode) async => [
    const Reference(bookId: 8, chapter: 4, verse: 17),
  ];

  @override
  Future<List<Reference>> searchExactMatchNoPunctuation(String word) async => [
    const Reference(bookId: 8, chapter: 4, verse: 17),
  ];

  @override
  Future<List<HebrewGreekWord>> wordsForVerse(
    Reference reference, {
    bool includeStrongs = false,
  }) async => [
    HebrewGreekWord(
      id: 'w1',
      reference: reference,
      text: 'דָּוִד',
      strongsCode: 'H1732',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResourceService implements ResourceService {
  @override
  Future<bool> resourceExists(ResourceType type, String id) async => false;

  @override
  Future<String> getResourceLocalPath(ResourceType type, String id) async =>
      '/mock/$id.db';

  @override
  Future<List<Resource>> getResourcesByType(
    ResourceType resourceType, {
    bool includeRemoved = true,
    String? langCode,
  }) async => [];

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
  String? get currentBibleId => 'test_bible';
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

class FakeReadingSessionService implements ReadingSessionService {
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAppGuideManager implements AppGuideManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGlossService implements GlossService {
  @override
  Future<GlossResult?> glossForId({
    required String wordId,
    void Function(String)? onDatabaseMissing,
  }) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeManager homeManager;

  const testWord = WordDetails(
    word: 'דָּוִד',
    gloss: 'David',
    glossIsAi: false,
    glossTextDirection: TextDirection.ltr,
    strongsCode: 'H1732',
    grammar: 'Np-ms',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    final settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<DownloadService>(FakeDownloadService());
    getIt.registerSingleton<ResourceService>(FakeResourceService());
    getIt.registerSingleton<HebrewGreekDatabase>(FakeHebrewGreekDatabase());
    getIt.registerSingleton<GlossService>(FakeGlossService());
    getIt.registerSingleton<BibleService>(FakeBibleService());
    getIt.registerSingleton<ReadingSessionService>(FakeReadingSessionService());
    getIt.registerSingleton<AppGuideManager>(FakeAppGuideManager());

    homeManager = HomeManager();
    getIt.registerSingleton<HomeManager>(homeManager);
  });

  tearDown(() {
    homeManager.dispose();
  });

  testWidgets('renders root title and table rows icon button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: SimilarVersesPage(word: testWord),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('דּוֹד'), findsOneWidget);
    expect(find.byIcon(Icons.table_rows_outlined), findsOneWidget);
    expect(find.byType(VerseListItem), findsOneWidget);
  });

  testWidgets('tapping reference jumps context on HomeManager', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SimilarVersesPage(word: testWord),
                      ),
                    );
                  },
                  child: const Text('Open Similar'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open SimilarVersesPage
    await tester.tap(find.text('Open Similar'));
    await tester.pumpAndSettle();

    expect(find.byType(SimilarVersesPage), findsOneWidget);

    // Tap the reference header
    // Book ID 8 is Ruth, chapter 4, verse 17 -> "Ruth 4:17"
    final refFinder = find.text('Ruth 4:17');
    expect(refFinder, findsOneWidget);
    await tester.tap(refFinder);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1600));

    // Verify popped back to root
    expect(find.byType(SimilarVersesPage), findsNothing);
    expect(find.text('Open Similar'), findsOneWidget);

    // Verify HomeManager received the search context
    final searchCtx = homeManager.searchContextNotifier.value;
    expect(searchCtx, isNotNull);
    expect(searchCtx!.word.word, 'דָּוִד');
    expect(
      searchCtx.anchorReference,
      const Reference(bookId: 8, chapter: 4, verse: 17),
    );
  });
}
