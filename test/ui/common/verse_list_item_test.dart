import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/common/word.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/resources/resource_language.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/verse_list_item.dart';
import 'package:gbt/ui/common/word_popup.dart';

class FakeGlossService implements GlossService {
  final Map<String, GlossResult> glosses;
  FakeGlossService({this.glosses = const {}});

  @override
  Future<GlossResult?> glossForId({
    required String wordId,
    void Function(String)? onDatabaseMissing,
  }) async {
    return glosses[wordId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<GlossService>(
      FakeGlossService(
        glosses: {
          'w1': const GlossResult(
            gloss: 'in the beginning',
            isAiGenerated: false,
            textDirection: ResourceLanguageTextDirection.ltr,
          ),
          'w2': const GlossResult(
            gloss: 'created',
            isAiGenerated: true,
            textDirection: ResourceLanguageTextDirection.ltr,
          ),
        },
      ),
    );
  });

  tearDown(() {
    WordPopup.dismissActive();
  });

  final testWords = [
    HebrewGreekWord(
      id: 'w1',
      reference: const Reference(bookId: 1, chapter: 1, verse: 1),
      text: 'בְּרֵאשִׁ֖ית',
      strongsCode: 'H7225',
    ),
    HebrewGreekWord(
      id: 'w2',
      reference: const Reference(bookId: 1, chapter: 1, verse: 1),
      text: 'בָּרָ֣א',
      strongsCode: 'H1254',
    ),
  ];

  testWidgets('renders reference and words from wordsFuture', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseListItem(
            formattedReference: 'Genesis 1:1',
            textDirection: TextDirection.rtl,
            wordsFuture: Future.value(testWords),
            highlightPredicate: (word) => word.strongsCode == 'H7225',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Genesis 1:1'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('בְּרֵאשִׁ֖ית'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders reference and spans from verseContentFuture', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseListItem(
            formattedReference: 'Genesis 1:1',
            textDirection: TextDirection.rtl,
            verseContentFuture: Future.value(
              const TextSpan(text: 'Custom verse content'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Genesis 1:1'), findsOneWidget);
    expect(find.text('Custom verse content'), findsOneWidget);
  });

  testWidgets('tapping reference calls onReferenceTapped callback', (
    tester,
  ) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseListItem(
            formattedReference: 'Genesis 1:1',
            textDirection: TextDirection.rtl,
            wordsFuture: Future.value(testWords),
            onReferenceTapped: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Genesis 1:1'));
    expect(tapped, isTrue);
  });

  testWidgets('renders parallel translation rows with badges', (tester) async {
    const parallels = [
      ParallelVerseData(
        bibleId: 'eng_ult',
        badge: 'ULT',
        text: 'In the beginning God created the heavens and the earth.',
      ),
      ParallelVerseData(
        bibleId: 'eng_bsb',
        badge: 'BSB',
        text: 'In the beginning God created the heavens and the earth.',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseListItem(
            formattedReference: 'Genesis 1:1',
            textDirection: TextDirection.rtl,
            wordsFuture: Future.value(testWords),
            parallelVerses: parallels,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ULT'), findsOneWidget);
    expect(find.text('BSB'), findsOneWidget);
    expect(
      find.text('In the beginning God created the heavens and the earth.'),
      findsNWidgets(2),
    );
  });

  testWidgets('tapping a word span triggers GlossService and shows WordPopup', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerseListItem(
            formattedReference: 'Genesis 1:1',
            textDirection: TextDirection.rtl,
            wordsFuture: Future.value(testWords),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find RichText widget for the verse and tap on the first word span
    final richTextFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('בְּרֵאשִׁ֖ית'),
    );
    expect(richTextFinder, findsOneWidget);

    final richText = tester.firstWidget<RichText>(richTextFinder);
    final rootSpan = richText.text as TextSpan;
    final verseSpan =
        (rootSpan.children != null &&
            rootSpan.children!.isNotEmpty &&
            rootSpan.children![0] is TextSpan &&
            (rootSpan.children![0] as TextSpan).children != null)
        ? rootSpan.children![0] as TextSpan
        : rootSpan;
    expect(verseSpan.children, isNotNull);
    expect(verseSpan.children!.length, 2);

    final firstSpan = verseSpan.children![0] as TextSpan;
    final recognizer = firstSpan.recognizer as TapGestureRecognizer;

    // Simulate tap up at an offset
    recognizer.onTapUp?.call(
      TapUpDetails(
        kind: PointerDeviceKind.touch,
        globalPosition: const Offset(100, 200),
      ),
    );

    await tester.pumpAndSettle();

    // Verify WordPopup appears with gloss
    expect(find.text('in the beginning'), findsOneWidget);

    // Verify dismissActive removes it
    WordPopup.dismissActive();
    await tester.pumpAndSettle();
    expect(find.text('in the beginning'), findsNothing);
  });
}
