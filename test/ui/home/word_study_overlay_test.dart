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
import 'package:gbt/services/lexicon/database.dart';
import 'package:gbt/services/reading_session/reading_session_service.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/floating_return_pill.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
import 'package:gbt/ui/home/word_details_dialog/word_details_dialog.dart';
import 'package:gbt/ui/home/word_study_overlay_layer.dart';
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
    getIt.registerSingleton<ReadingSessionService>(FakeReadingSessionService());
    getIt.registerSingleton<AppGuideManager>(FakeAppGuideManager());

    homeManager = HomeManager();
    getIt.registerSingleton<HomeManager>(homeManager);
  });

  tearDown(() {
    homeManager.dispose();
  });

  testWidgets(
    'WordStudyOverlayLayer lifecycle: display, navigate, offstage, restore original',
    (tester) async {
      homeManager.currentReference.value = const Reference(
        bookId: 1,
        chapter: 12,
        verse: 1,
      );
      homeManager.startWordStudy(wordId: 'w1', isRtl: true);

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
            body: Stack(
              children: [
                const Center(child: Text('Bible Reader at Genesis 12:1')),
                ListenableBuilder(
                  listenable: homeManager.wordStudySessionNotifier,
                  builder: (context, _) {
                    final session = homeManager.wordStudySessionNotifier.value;
                    if (session == null) return const SizedBox.shrink();

                    return Positioned.fill(
                      child: ListenableBuilder(
                        listenable: session.isOverlayVisibleNotifier,
                        builder: (context, _) {
                          return Offstage(
                            key: const Key('word_study_offstage'),
                            offstage: !session.isOverlayVisible,
                            child: WordStudyOverlayLayer(
                              session: session,
                              manager: homeManager,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: homeManager.searchContextNotifier,
                  builder: (context, _) {
                    final ctx = homeManager.searchContextNotifier.value;
                    if (ctx == null) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: FloatingReturnPill(contextData: ctx),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. WordDetailsDialog is visible initially
      expect(find.byType(WordDetailsDialog), findsOneWidget);
      expect(find.byType(SimilarVersesPage), findsNothing);

      // 2. Tap list icon in WordDetailsDialog to open occurrences
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      expect(find.byType(SimilarVersesPage), findsOneWidget);

      // 3. In SimilarVersesPage, tap a verse reference (Ruth 4:17) to preview context
      final refFinder = find.text('Ruth 4:17');
      expect(refFinder, findsOneWidget);
      await tester.tap(refFinder);
      await tester.pumpAndSettle();
      await tester.pump(
        const Duration(milliseconds: 1600),
      ); // Advance flash timer

      // Reader jumped to preview reference
      expect(
        homeManager.currentReference.value,
        const Reference(bookId: 8, chapter: 4, verse: 17),
      );

      // Overlay is now OFFSTAGE
      final session = homeManager.wordStudySessionNotifier.value!;
      expect(session.isOverlayVisible, isFalse);

      // Return pill is visible
      expect(find.byType(FloatingReturnPill), findsOneWidget);

      // SimilarVersesPage is still mounted in element tree but offstage
      final offstageFinder = find.byKey(const Key('word_study_offstage'));
      expect(offstageFinder, findsOneWidget);
      final offstageWidget = tester.widget<Offstage>(offstageFinder);
      expect(offstageWidget.offstage, isTrue);

      // 4. Tap the return pill body to return to occurrences list
      await tester.tap(find.text('דָּוִד'));
      await tester.pumpAndSettle();

      // Overlay is now ONSTAGE immediately without rebuilding
      expect(session.isOverlayVisible, isTrue);
      final offstageWidgetAfter = tester.widget<Offstage>(
        find.byKey(const Key('word_study_offstage')),
      );
      expect(offstageWidgetAfter.offstage, isFalse);
      expect(find.byType(SimilarVersesPage), findsOneWidget);

      // 5. Tap the AppBar back button on SimilarVersesPage
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // SimilarVersesPage popped, revealing WordDetailsDialog
      expect(find.byType(SimilarVersesPage), findsNothing);
      expect(find.byType(WordDetailsDialog), findsOneWidget);

      // 6. Dismiss WordDetailsDialog via close icon
      await tester.tap(
        find.descendant(
          of: find.byType(WordDetailsDialog),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(homeManager.flashedWordIdNotifier.value, 'w1');

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1600));

      // Dialog dismissed, overlay unmounted
      expect(homeManager.wordStudySessionNotifier.value, isNull);
      expect(find.byType(WordDetailsDialog), findsNothing);
      expect(homeManager.flashedWordIdNotifier.value, isNull);

      // Reader automatically returned to original reading location (Genesis 12:1)!
      expect(
        homeManager.currentReference.value,
        const Reference(bookId: 1, chapter: 12, verse: 1),
      );
    },
  );

  testWidgets(
    'FloatingReturnPill close icon stays at current location and discards session',
    (tester) async {
      homeManager.currentReference.value = const Reference(
        bookId: 1,
        chapter: 12,
        verse: 1,
      );
      homeManager.startWordStudy(wordId: 'w1', isRtl: true);

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
            body: Stack(
              children: [
                const Center(child: Text('Bible Reader')),
                ListenableBuilder(
                  listenable: homeManager.wordStudySessionNotifier,
                  builder: (context, _) {
                    final session = homeManager.wordStudySessionNotifier.value;
                    if (session == null) return const SizedBox.shrink();

                    return Positioned.fill(
                      child: ListenableBuilder(
                        listenable: session.isOverlayVisibleNotifier,
                        builder: (context, _) {
                          return Offstage(
                            key: const Key('word_study_offstage'),
                            offstage: !session.isOverlayVisible,
                            child: WordStudyOverlayLayer(
                              session: session,
                              manager: homeManager,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                ListenableBuilder(
                  listenable: homeManager.searchContextNotifier,
                  builder: (context, _) {
                    final ctx = homeManager.searchContextNotifier.value;
                    if (ctx == null) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: FloatingReturnPill(contextData: ctx),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open occurrences
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      // Tap reference to preview context
      await tester.tap(find.text('Ruth 4:17'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1600));

      // Tap 'x' on return pill
      await tester.tap(
        find.descendant(
          of: find.byType(FloatingReturnPill),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();

      // Session is discarded
      expect(homeManager.wordStudySessionNotifier.value, isNull);
      expect(homeManager.searchContextNotifier.value, isNull);
      expect(find.byType(FloatingReturnPill), findsNothing);

      // Reader STAYS at previewed location (Ruth 4:17)
      expect(
        homeManager.currentReference.value,
        const Reference(bookId: 8, chapter: 4, verse: 17),
      );
    },
  );
}
