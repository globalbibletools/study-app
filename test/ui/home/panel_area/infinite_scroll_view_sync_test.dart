import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/bible_navigation.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/common/navigation_view_model.dart';
import '../common/fake_user_settings.dart';
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
  const _FakeChapter({
    required this.bookId,
    required this.chapter,
    required this.geometry,
    this.height = _chapterHeight,
    this.publishGeometry = true,
  });

  final int bookId;
  final int chapter;
  final ChapterGeometry geometry;
  final double height;
  final bool publishGeometry;

  @override
  State<_FakeChapter> createState() => _FakeChapterState();
}

class _FakeChapterState extends State<_FakeChapter> {
  @override
  void initState() {
    super.initState();
    _publishGeometry();
  }

  @override
  void didUpdateWidget(covariant _FakeChapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.geometry != oldWidget.geometry ||
        widget.height != oldWidget.height ||
        widget.publishGeometry != oldWidget.publishGeometry) {
      _publishGeometry();
    }
  }

  void _publishGeometry() {
    if (!widget.publishGeometry) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.publishGeometry) return;
      ChapterGeometryChangedNotification(
        bookId: widget.bookId,
        chapter: widget.chapter,
        geometry: widget.geometry,
      ).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: widget.height, width: double.infinity);
  }
}

Widget _panel({
  required Key key,
  required NavigationViewModel controller,
  required int bookId,
  required int chapter,
  required ChapterGeometry Function(int bookId, int chapter) geometryFor,
  double chapterHeight = _chapterHeight,
  bool publishGeometry = true,
}) {
  return SizedBox(
    key: key,
    height: 50,
    child: InfiniteScrollView(
      bookId: bookId,
      chapter: chapter,
      navigationViewModel: controller,
      chapterBuilder: (context, bId, ch) => _FakeChapter(
        bookId: bId,
        chapter: ch,
        geometry: geometryFor(bId, ch),
        height: chapterHeight,
        publishGeometry: publishGeometry,
      ),
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
    final controller = NavigationViewModel(FakeUserSettings());
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
    final controller = NavigationViewModel(FakeUserSettings());
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
    controller.reportPosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      display: null,
    );
    await tester.pump();

    // Verses 1 and 2 each measure 25px once verse 3 is removed.
    expect(_pixels(tester, followerKey), closeTo(50, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('zero-height follower verse resolves both edges to one point', (
    tester,
  ) async {
    final controller = NavigationViewModel(FakeUserSettings());
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
    controller.reportPosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      display: null,
    );
    await tester.pump();

    // Verse 3 starts at 40px and owns no lines.
    expect(_pixels(tester, followerKey), closeTo(40, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('cross-chapter boundary has no gap', (tester) async {
    final controller = NavigationViewModel(FakeUserSettings());
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

    controller.setActiveSource('leader');

    void report(double t) {
      controller.reportPosition(
        'leader',
        SyncPosition(
          Anchor(
            const Reference(bookId: 1, chapter: 1, verse: 5),
            AnchorEnd.end,
          ),
          Anchor(
            const Reference(bookId: 1, chapter: 2, verse: 1),
            AnchorEnd.start,
          ),
          t,
        ),
        display: null,
      );
    }

    report(0);
    await tester.pump();
    final atBoundary = _pixels(tester, followerKey);

    report(1);
    await tester.pump();
    expect(_pixels(tester, followerKey), closeTo(atBoundary, 0.5));

    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('far-away controller truth re-centers the follower', (
    tester,
  ) async {
    final controller = NavigationViewModel(FakeUserSettings());
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
    controller.reportPosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 3, verse: 1),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 3, verse: 1), AnchorEnd.end),
        0.5,
      ),
      display: null,
    );
    await tester.pump();
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(10, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('a reopened panel aligns to the controller truth', (
    tester,
  ) async {
    final controller = NavigationViewModel(FakeUserSettings());
    const followerKey = Key('follower');

    controller.setActiveSource('leader');
    controller.reportPosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      display: null,
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
    final controller = NavigationViewModel(FakeUserSettings());
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
    controller.reportPosition(
      'leader',
      SyncPosition(
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 3),
          AnchorEnd.start,
        ),
        Anchor(const Reference(bookId: 1, chapter: 1, verse: 3), AnchorEnd.end),
        0.5,
      ),
      display: null,
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

  testWidgets('null top anchor maps to the top of the chapter', (tester) async {
    final controller = NavigationViewModel(FakeUserSettings());
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
    controller.reportPosition(
      'leader',
      SyncPosition(
        const Anchor.top(),
        Anchor(
          const Reference(bookId: 1, chapter: 1, verse: 1),
          AnchorEnd.start,
        ),
        0.5,
      ),
      display: null,
    );
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(0, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets(
    'a follower-only verse is skipped when the leader jumps over it',
    (tester) async {
      final controller = NavigationViewModel(FakeUserSettings());
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

      void report(int verse, double t) {
        controller.reportPosition(
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
          display: null,
        );
      }

      report(1, 1);
      await tester.pump();
      final atBoundary = _pixels(tester, followerKey);
      expect(atBoundary, closeTo(20, 0.5));

      report(3, 0);
      await tester.pump();
      expect(_pixels(tester, followerKey), closeTo(atBoundary + 20, 0.5));

      await tester.pump(const Duration(milliseconds: 250));
    },
  );

  testWidgets('audio-driven seek animates to the target verse', (tester) async {
    final controller = NavigationViewModel(FakeUserSettings());
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

    controller.seekTo(
      const Reference(bookId: 1, chapter: 2, verse: 4),
      animated: true,
    );
    await tester.pumpAndSettle();

    // Verse 4 starts at 60px; the seek keeps 16px of breathing room.
    expect(_pixels(tester, followerKey), closeTo(44, 0.5));
    expect(controller.position, isNotNull);
    expect(
      controller.displayReference,
      const Reference(bookId: 1, chapter: 2, verse: 4),
    );
  });

  testWidgets('manual seek jumps to the target verse with breathing room', (
    tester,
  ) async {
    final controller = NavigationViewModel(FakeUserSettings());
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

    controller.seekTo(const Reference(bookId: 1, chapter: 2, verse: 4));
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(44, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('a seek before geometry is published completes on publish', (
    tester,
  ) async {
    final controller = NavigationViewModel(FakeUserSettings());
    const followerKey = Key('follower');
    var publishGeometry = false;

    Widget buildPanel() => MaterialApp(
      home: Scaffold(
        body: _panel(
          key: followerKey,
          controller: controller,
          bookId: 1,
          chapter: 2,
          publishGeometry: publishGeometry,
          geometryFor: (_, _) => _verseGeometry(),
        ),
      ),
    );

    await tester.pumpWidget(buildPanel());
    await tester.pump();

    controller.seekTo(const Reference(bookId: 1, chapter: 2, verse: 4));
    await tester.pump();

    // No geometry yet: alignment is a silent no-op, not a retry poll.
    expect(_pixels(tester, followerKey), closeTo(0, 0.5));

    publishGeometry = true;
    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.pump();

    expect(_pixels(tester, followerKey), closeTo(44, 0.5));
    await tester.pump(const Duration(milliseconds: 250));
  });
}
