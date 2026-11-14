import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/hebrew_greek/database.dart';
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/floating_return_pill.dart';
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
  }) async => [];

  @override
  Future<HebrewGreekWord?> getWordForId(String wordId) async => HebrewGreekWord(
    id: wordId,
    reference: const Reference(bookId: 8, chapter: 4, verse: 17),
    text: 'דָּוִד',
    strongsCode: 'H1732',
  );

  @override
  Future<(String, String)?> getStrongsAndGrammar(String wordId) async =>
      ('H1732', 'Np-ms');

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

class FakeLexiconsDatabase implements LexiconsDatabase {
  @override
  Future<List<LexiconMeaning>> getMeaningsForStrongs(String strongs) async =>
      [];

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

  late HomeManager homeManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    final settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<DownloadService>(FakeDownloadService());
    getIt.registerSingleton<ResourceService>(FakeResourceService());
    getIt.registerSingleton<BibleService>(FakeBibleService());
    getIt.registerSingleton<HebrewGreekDatabase>(FakeHebrewGreekDatabase());
    getIt.registerSingleton<GlossService>(FakeGlossService());
    getIt.registerSingleton<LexiconsDatabase>(FakeLexiconsDatabase());
    getIt.registerSingleton<ReadingSessionViewModel>(
      FakeReadingSessionViewModel(),
    );
    getIt.registerSingleton<AppGuideManager>(FakeAppGuideManager());

    homeManager = HomeManager();
    getIt.registerSingleton<HomeManager>(homeManager);
  });

  tearDown(() {
    homeManager.dispose();
  });

  const testWord = WordDetails(
    word: 'דָּוִד',
    gloss: 'David',
    glossIsAi: false,
    glossTextDirection: TextDirection.ltr,
    strongsCode: 'H1732',
    grammar: 'Np-ms',
  );

  const testContext = OccurrenceSearchContext(
    word: testWord,
    searchType: SearchType.root,
    anchorReference: Reference(bookId: 8, chapter: 4, verse: 17),
  );

  testWidgets('renders lemma text, back arrow, and close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: FloatingReturnPill(contextData: testContext)),
        ),
      ),
    );

    expect(find.text('דָּוִד'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets(
    'tapping close icon calls dismissWordStudySession on HomeManager',
    (tester) async {
      homeManager.startWordStudy(wordId: 'w1', isRtl: true);
      homeManager.searchContextNotifier.value = testContext;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: FloatingReturnPill(contextData: testContext)),
          ),
        ),
      );

      expect(homeManager.searchContextNotifier.value, isNotNull);
      expect(homeManager.wordStudySessionNotifier.value, isNotNull);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(homeManager.searchContextNotifier.value, isNull);
      expect(homeManager.wordStudySessionNotifier.value, isNull);
    },
  );

  testWidgets(
    'tapping pill body calls setWordStudyOverlayVisible on HomeManager',
    (tester) async {
      homeManager.startWordStudy(wordId: 'w1', isRtl: true);
      homeManager.setWordStudyOverlayVisible(false);
      homeManager.searchContextNotifier.value = testContext;

      expect(
        homeManager.wordStudySessionNotifier.value?.isOverlayVisible,
        isFalse,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: FloatingReturnPill(contextData: testContext)),
          ),
        ),
      );

      // Tap the pill's back/lemma section
      await tester.tap(find.text('דָּוִד'));
      await tester.pump();

      expect(
        homeManager.wordStudySessionNotifier.value?.isOverlayVisible,
        isTrue,
      );
    },
  );
}
