import 'dart:ui' show TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/app_guide/app_guide_manager.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/home_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/dialog_manager.dart';
import 'package:gbt/ui/home/word_details_dialog/similar_verses/similar_verses_page.dart';
import 'package:scripture/scripture.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeResourceService implements ResourceService {
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

class FakeReadingSessionManager implements ReadingSessionManager {
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

  group('HomeManager Context Navigation & Pill Lifecycle', () {
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
      getIt.registerSingleton<ReadingSessionManager>(
        FakeReadingSessionManager(),
      );
      getIt.registerSingleton<AppGuideManager>(FakeAppGuideManager());

      homeManager = HomeManager();
      getIt.registerSingleton<HomeManager>(homeManager);
      await homeManager.init();
    });

    tearDown(() {
      homeManager.dispose();
    });

    test(
      'jumpToContextReference updates searchContextNotifier and currentReference',
      () {
        const targetRef = Reference(bookId: 8, chapter: 4, verse: 17);
        const word = WordDetails(
          word: 'דָּוִד',
          gloss: 'David',
          glossIsAi: false,
          glossTextDirection: TextDirection.ltr,
          strongsCode: 'H1732',
          grammar: 'Np-ms',
        );

        final context = OccurrenceSearchContext(
          word: word,
          searchType: SearchType.root,
          anchorReference: targetRef,
        );

        homeManager.jumpToContextReference(context);

        expect(homeManager.searchContextNotifier.value, equals(context));
        expect(homeManager.currentReference.value, equals(targetRef));
        expect(homeManager.panelAnchorNotifier.value, equals(targetRef));
      },
    );

    test(
      'jumpToContextReference across different books switches bookId and chapter',
      () {
        homeManager.currentReference.value = const Reference(
          bookId: 1,
          chapter: 1,
          verse: 1,
        );

        const targetRef = Reference(bookId: 19, chapter: 23, verse: 1);
        const word = WordDetails(
          word: 'מִזְמוֹר',
          gloss: 'Psalm',
          glossIsAi: false,
          glossTextDirection: TextDirection.ltr,
          strongsCode: 'H4210',
          grammar: 'Nc-ms',
        );

        final context = OccurrenceSearchContext(
          word: word,
          searchType: SearchType.exact,
          anchorReference: targetRef,
        );

        homeManager.jumpToContextReference(context);

        expect(homeManager.currentReference.value.bookId, 19);
        expect(homeManager.currentReference.value.chapter, 23);
        expect(homeManager.currentReference.value.verse, 1);
        expect(homeManager.panelAnchorNotifier.value, equals(targetRef));
      },
    );

    test('clearSearchContext resets searchContextNotifier to null', () {
      const targetRef = Reference(bookId: 8, chapter: 4, verse: 17);
      const word = WordDetails(
        word: 'דָּוִד',
        gloss: 'David',
        glossIsAi: false,
        glossTextDirection: TextDirection.ltr,
        strongsCode: 'H1732',
        grammar: 'Np-ms',
      );

      homeManager.jumpToContextReference(
        OccurrenceSearchContext(
          word: word,
          searchType: SearchType.root,
          anchorReference: targetRef,
        ),
      );

      expect(homeManager.searchContextNotifier.value, isNotNull);

      homeManager.clearSearchContext();
      expect(homeManager.searchContextNotifier.value, isNull);
    });

    test('onChapterSelected clears active search context', () {
      const targetRef = Reference(bookId: 8, chapter: 4, verse: 17);
      const word = WordDetails(
        word: 'דָּוִד',
        gloss: 'David',
        glossIsAi: false,
        glossTextDirection: TextDirection.ltr,
        strongsCode: 'H1732',
        grammar: 'Np-ms',
      );

      homeManager.jumpToContextReference(
        OccurrenceSearchContext(
          word: word,
          searchType: SearchType.root,
          anchorReference: targetRef,
        ),
      );

      expect(homeManager.searchContextNotifier.value, isNotNull);

      // User selects a different chapter from AppBar
      homeManager.onChapterSelected(2);
      expect(homeManager.searchContextNotifier.value, isNull);
    });

    testWidgets('flashVerse sets highlight and clears it after 1.5 seconds', (
      tester,
    ) async {
      const targetRef = Reference(bookId: 8, chapter: 4, verse: 17);
      homeManager.flashVerse(targetRef);

      expect(
        homeManager.audioPlayerViewModel.reference.value,
        equals(targetRef),
      );

      await tester.pump(const Duration(milliseconds: 1000));
      expect(
        homeManager.audioPlayerViewModel.reference.value,
        equals(targetRef),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(homeManager.audioPlayerViewModel.reference.value, isNull);
    });

    test('jumpToContextReference sets pendingVerseJump on syncController', () {
      const targetRef = Reference(bookId: 8, chapter: 4, verse: 17);
      const word = WordDetails(
        word: 'דָּוִד',
        gloss: 'David',
        glossIsAi: false,
        glossTextDirection: TextDirection.ltr,
        strongsCode: 'H1732',
        grammar: 'Np-ms',
      );

      final context = OccurrenceSearchContext(
        word: word,
        searchType: SearchType.root,
        anchorReference: targetRef,
      );

      homeManager.jumpToContextReference(context);

      expect(homeManager.syncController.pendingVerseJump, isNotNull);
      expect(homeManager.syncController.pendingVerseJump!.bookId, 8);
      expect(homeManager.syncController.pendingVerseJump!.chapter, 4);
      expect(homeManager.syncController.pendingVerseJump!.verse, 17);
    });

    test('startWordStudy captures originalReference and creates session', () {
      homeManager.currentReference.value = const Reference(
        bookId: 1,
        chapter: 12,
        verse: 1,
      );

      homeManager.startWordStudy(wordId: 'w1', isRtl: true);

      final session = homeManager.wordStudySessionNotifier.value;
      expect(session, isNotNull);
      expect(session!.wordId, 'w1');
      expect(session.isRtl, isTrue);
      expect(
        session.originalReference,
        const Reference(bookId: 1, chapter: 12, verse: 1),
      );
      expect(session.isOverlayVisible, isTrue);
    });

    test('setWordStudyOverlayVisible toggles isOverlayVisible', () {
      homeManager.startWordStudy(wordId: 'w1', isRtl: true);
      final session = homeManager.wordStudySessionNotifier.value!;

      expect(session.isOverlayVisible, isTrue);

      homeManager.setWordStudyOverlayVisible(false);
      expect(session.isOverlayVisible, isFalse);

      homeManager.setWordStudyOverlayVisible(true);
      expect(session.isOverlayVisible, isTrue);
    });

    test(
      'dismissWordStudySession(keepCurrentLocation: false) restores originalReference',
      () {
        homeManager.currentReference.value = const Reference(
          bookId: 1,
          chapter: 12,
          verse: 1,
        );
        homeManager.startWordStudy(wordId: 'w1', isRtl: true);

        // User jumps to a different reference to preview
        const previewRef = Reference(bookId: 8, chapter: 4, verse: 17);
        const word = WordDetails(
          word: 'דָּוִד',
          gloss: 'David',
          glossIsAi: false,
          glossTextDirection: TextDirection.ltr,
          strongsCode: 'H1732',
          grammar: 'Np-ms',
        );
        homeManager.jumpToContextReference(
          const OccurrenceSearchContext(
            word: word,
            searchType: SearchType.root,
            anchorReference: previewRef,
          ),
        );

        expect(homeManager.currentReference.value, equals(previewRef));

        // User dismisses dialog (keepCurrentLocation: false)
        homeManager.dismissWordStudySession(keepCurrentLocation: false);

        expect(homeManager.wordStudySessionNotifier.value, isNull);
        expect(homeManager.searchContextNotifier.value, isNull);
        // Reader restored to original location!
        expect(
          homeManager.currentReference.value,
          const Reference(bookId: 1, chapter: 12, verse: 1),
        );
        expect(
          homeManager.panelAnchorNotifier.value,
          const Reference(bookId: 1, chapter: 12, verse: 1),
        );
        // Word is flashed upon returning!
        expect(homeManager.flashedWordIdNotifier.value, 'w1');
      },
    );

    testWidgets(
      'flashWord sets flashedWordId and clears it after 1.5 seconds',
      (tester) async {
        homeManager.flashWord('w1');

        expect(homeManager.flashedWordIdNotifier.value, 'w1');

        await tester.pump(const Duration(milliseconds: 1000));
        expect(homeManager.flashedWordIdNotifier.value, 'w1');

        await tester.pump(const Duration(milliseconds: 600));
        expect(homeManager.flashedWordIdNotifier.value, isNull);
      },
    );

    test(
      'dismissWordStudySession(keepCurrentLocation: true) stays at current location',
      () {
        homeManager.currentReference.value = const Reference(
          bookId: 1,
          chapter: 12,
          verse: 1,
        );
        homeManager.startWordStudy(wordId: 'w1', isRtl: true);

        // User jumps to preview
        const previewRef = Reference(bookId: 8, chapter: 4, verse: 17);
        const word = WordDetails(
          word: 'דָּוִד',
          gloss: 'David',
          glossIsAi: false,
          glossTextDirection: TextDirection.ltr,
          strongsCode: 'H1732',
          grammar: 'Np-ms',
        );
        homeManager.jumpToContextReference(
          const OccurrenceSearchContext(
            word: word,
            searchType: SearchType.root,
            anchorReference: previewRef,
          ),
        );

        expect(homeManager.currentReference.value, equals(previewRef));

        // User taps 'x' on return pill (keepCurrentLocation: true)
        homeManager.dismissWordStudySession(keepCurrentLocation: true);

        expect(homeManager.wordStudySessionNotifier.value, isNull);
        expect(homeManager.searchContextNotifier.value, isNull);
        // Reader stays at previewed location!
        expect(homeManager.currentReference.value, equals(previewRef));
      },
    );
  });
}
