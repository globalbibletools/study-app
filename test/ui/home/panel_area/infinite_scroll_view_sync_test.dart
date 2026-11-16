import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/scroll_sync_controller.dart';
import 'package:gbt/ui/home/panel_area/common/infinite_scroll_view.dart';

const _chapterHeight = 100.0;

ChapterGeometry _verseGeometry({
  int count = 5,
  double lead = 0,
  double height = _chapterHeight,
  Set<int> missing = const {},
  Set<int> zero = const {},
}) {
  final spans = <int, VerseSpan>{};
  final available = height - lead;
  final effectiveCount = count - missing.length;
  final verseHeight = effectiveCount == 0 ? 0.0 : available / effectiveCount;
  var cursor = lead;
  for (var verse = 1; verse <= count; verse++) {
    if (missing.contains(verse)) continue;
    final spanHeight = zero.contains(verse) ? 0.0 : verseHeight;
    spans[verse] = VerseSpan(
      verse: verse,
      start: cursor,
      end: cursor + spanHeight,
    );
    cursor += spanHeight;
  }
  return ChapterGeometry(spans: spans);
}

class _FakeChapter extends StatefulWidget {
  const _FakeChapter({required this.geometry, this.height = _chapterHeight});

  final ChapterGeometry geometry;
  final double height;

  @override
  State<_FakeChapter> createState() => _FakeChapterState();
}

class _FakeChapterState extends State<_FakeChapter>
    with ChapterGeometryProvider {
  @override
  ChapterGeometry? get geometry => widget.geometry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: widget.height, width: double.infinity);
  }
}

Widget _panel({
  required Key key,
  required ScrollSyncController controller,
  required int bookId,
  required int chapter,
  required ChapterGeometry Function(int bookId, int chapter) geometryFor,
  double chapterHeight = _chapterHeight,
}) {
  return SizedBox(
    key: key,
    height: 50,
    child: InfiniteScrollView(
      bookId: bookId,
      chapter: chapter,
      syncController: controller,
      chapterBuilder: (context, bId, ch) =>
          _FakeChapter(geometry: geometryFor(bId, ch), height: chapterHeight),
    ),
  );
}

double _pixels(WidgetTester tester, Key key) {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
        .first,
  );
  return scrollable.position.pixels;
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<BibleNavigation>(
      BibleNavigation.withCounts({(1, 1): 5, (1, 2): 5, (1, 3): 5}),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('two identical panels stay in sync while dragging', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const leaderKey = Key('leader');
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              _panel(
                key: leaderKey,
                controller: controller,
                bookId: 1,
                chapter: 2,
                geometryFor: (_, _) => _verseGeometry(),
              ),
              _panel(
                key: followerKey,
                controller: controller,
                bookId: 1,
                chapter: 2,
                geometryFor: (_, _) => _verseGeometry(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byKey(leaderKey), const Offset(0, -40));
    await tester.pump();

    expect(_pixels(tester, leaderKey), greaterThan(0));
    expect(
      _pixels(tester, followerKey),
      closeTo(_pixels(tester, leaderKey), 1),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  });

  testWidgets('missing follower verse parks at the previous verse end', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 1,
            geometryFor: (_, _) => _verseGeometry(missing: {3}),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      displayReference: null,
    );
    await tester.pump();

    // Verses 1 and 2 each measure 25px once verse 3 is removed.
    expect(_pixels(tester, followerKey), closeTo(50, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('zero-height follower verse resolves both edges to one point', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 1,
            geometryFor: (_, _) => _verseGeometry(zero: {3}),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      displayReference: null,
    );
    await tester.pump();

    // Verse 3 starts at 40px and owns no lines.
    expect(_pixels(tester, followerKey), closeTo(40, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('cross-chapter gap resolves between last and first verse', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 2,
            geometryFor: (_, chapter) =>
                chapter == 1 ? _verseGeometry() : _verseGeometry(lead: 10),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 5), AnchorEnd.end),
        Anchor(
          const Reference(bookId: 1, chapter: 2, verse: 1),
          AnchorEnd.start,
        ),
        0.5,
      ),
      displayReference: null,
    );
    await tester.pump();

    // Chapter 1 ends at global 0 and chapter 2's first verse starts at 10.
    expect(_pixels(tester, followerKey), closeTo(5, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('far-away controller truth re-centers the follower', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 1,
            geometryFor: (_, _) => _verseGeometry(),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 3, verse: 1),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 3, verse: 1), AnchorEnd.end),
        0.5,
      ),
      displayReference: null,
    );
    await tester.pump();
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(10, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('a reopened panel aligns to the controller truth', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      displayReference: null,
    );

    Widget buildPanel() => MaterialApp(
      home: Scaffold(
        body: _panel(
          key: followerKey,
          controller: controller,
          bookId: 1,
          chapter: 1,
          geometryFor: (_, _) => _verseGeometry(),
        ),
      ),
    );

    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(50, 0.5));

    // Close the panel, then reopen it; the controller still holds the truth.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(50, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('follower re-aligns after a chapter layout change', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');
    var chapterHeight = 100.0;

    Widget buildPanel() => MaterialApp(
      home: Scaffold(
        body: _panel(
          key: followerKey,
          controller: controller,
          bookId: 1,
          chapter: 1,
          chapterHeight: chapterHeight,
          geometryFor: (_, _) => _verseGeometry(height: chapterHeight),
        ),
      ),
    );

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      displayReference: null,
    );

    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.pump();
    expect(_pixels(tester, followerKey), closeTo(50, 0.5));

    // Doubling the chapter height moves verse 3's midpoint to 100px.
    chapterHeight = 200;
    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.pump();
    expect(_pixels(tester, followerKey), closeTo(100, 0.5));

    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('null top anchor maps to the top of loaded content', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 1,
            geometryFor: (_, _) => _verseGeometry(lead: 20),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');
    controller.updatePosition(
      'leader',
      SyncPosition(
        const Anchor.top(),
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 1),
          AnchorEnd.start,
        ),
        0.5,
      ),
      displayReference: null,
    );
    await tester.pump();

    // The leader's leading-gap report expands the verse-1 anchor by half the
    // follower's 20px leading gap, so t=0.5 lands at 10px: the follower
    // traverses the top half of its gap during the leader's gap and the
    // bottom half while verse 1 scrolls in.
    expect(_pixels(tester, followerKey), closeTo(5, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('a gap that exists only on the follower is absorbed', (
    tester,
  ) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    // Follower-only gap of 20px between verses 1 and 2.
    final spans = {
      1: const VerseSpan(verse: 1, start: 0, end: 40),
      2: const VerseSpan(verse: 2, start: 60, end: 100),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 1,
            geometryFor: (_, _) => ChapterGeometry(spans: spans),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.setActiveSource('leader');

    void report(int verse, double t) {
      controller.updatePosition(
        'leader',
        SyncPosition(
          Anchor(
            Reference(bookId: 1, chapter: 1, verse: verse),
            AnchorEnd.start,
          ),
          Anchor(
            Reference(bookId: 1, chapter: 1, verse: verse),
            AnchorEnd.end,
          ),
          t,
        ),
        displayReference: null,
      );
    }

    // The leader reaches the end of its verse 1: the follower sits at the
    // midpoint of its own gap instead of its verse-1 end.
    report(1, 1);
    await tester.pump();
    final atBoundary = _pixels(tester, followerKey);
    expect(atBoundary, closeTo(50, 0.5));

    // The leader crosses into verse 2 (it has no gap there): the follower
    // does not jump over its gap — it continues from the same pixel.
    report(2, 0);
    await tester.pump();
    expect(_pixels(tester, followerKey), closeTo(atBoundary, 0.5));

    // And mid-verse 2 the follower is proportionally through its verse 2.
    report(2, 0.5);
    await tester.pump();
    expect(_pixels(tester, followerKey), closeTo(75, 0.5));

    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('audio-driven jump scrolls to the target verse', (tester) async {
    final controller = ScrollSyncController();
    const followerKey = Key('follower');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _panel(
            key: followerKey,
            controller: controller,
            bookId: 1,
            chapter: 2,
            geometryFor: (_, _) => _verseGeometry(),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.jumpToVerse(1, 2, 4, isAuto: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // Verse 4 starts at 60px; the jump keeps 16px of breathing room.
    expect(_pixels(tester, followerKey), closeTo(44, 0.5));
    expect(controller.position, isNotNull);
    expect(
      controller.displayReference,
      const Reference(bookId: 1, chapter: 2, verse: 4),
    );
    await tester.pump(const Duration(milliseconds: 250));
  });
}
