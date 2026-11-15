import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/bible/bible_service.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/home/panel_area/bible_panel/bible_chapter.dart';
import 'package:gbt/ui/home/panel_area/common/verse_sync_layout.dart';
import 'package:scripture/scripture.dart';
import 'package:scripture/scripture_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBibleService implements BibleService {
  _FakeBibleService(this.lines);

  final List<UsfmLine> lines;

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
  }) async => lines;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<UsfmLine> _lines() => [
  UsfmLine(
    bookChapterVerse: 1001001,
    text: 'In the beginning God created the heavens and the earth.',
    format: ParagraphFormat.p,
  ),
  UsfmLine(
    bookChapterVerse: 1001002,
    text: 'And the earth was without form and void.',
    format: ParagraphFormat.p,
  ),
  UsfmLine(
    bookChapterVerse: 1001003,
    text: 'And God said, Let there be light.',
    format: ParagraphFormat.p,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();

    final settings = UserSettings();
    await settings.init();
    getIt.registerSingleton<UserSettings>(settings);
    getIt.registerSingleton<BibleService>(_FakeBibleService(_lines()));
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<ChapterGeometry> pumpAndReadGeometry(
    WidgetTester tester,
    VerseLayout layout,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BibleChapter(bookId: 1, chapter: 1, verseLayout: layout),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<State<BibleChapter>>(find.byType(BibleChapter));
    final provider = state as ChapterGeometryProvider;
    expect(provider.geometry, isNotNull);
    return provider.geometry!;
  }

  void expectValidGeometry(ChapterGeometry geometry) {
    expect(geometry.spans.keys, containsAll([1, 2, 3]));

    final spans = geometry.spans.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    expect(spans.first.start, greaterThan(0), reason: 'chapter title gap');
    for (var i = 0; i < spans.length; i++) {
      expect(spans[i].end, greaterThanOrEqualTo(spans[i].start));
      if (i > 0) {
        expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].start));
        expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].end - 0.01));
      }
    }

    expect(geometry.gaps, isNotEmpty);
    expect(geometry.gaps.first.start, 0);

    // The chapter title is attributed to verse 1: its span starts at the
    // title's top (container padding 8 + spacer 10 = 18px with the test
    // font), so the leading gap is only the blank space above the title —
    // not the 30px title itself.
    expect(geometry.spans[1]!.start, closeTo(18, 3));
    expect(geometry.gaps.first.end, closeTo(18, 3));
  }

  testWidgets('paragraph layout measures verse numbers from RenderPassage', (
    tester,
  ) async {
    final geometry = await pumpAndReadGeometry(tester, VerseLayout.paragraph);
    expectValidGeometry(geometry);
  });

  testWidgets(
    'verse-per-line layout measures verse numbers from RenderPassage',
    (tester) async {
      final geometry = await pumpAndReadGeometry(
        tester,
        VerseLayout.versePerLine,
      );
      expectValidGeometry(geometry);
    },
  );
}
