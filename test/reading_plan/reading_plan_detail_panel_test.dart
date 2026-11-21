import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_session_view_model.dart';

class FakeDetailPlanService extends Fake implements ReadingPlanService {
  FakeDetailPlanService({
    this.bookStats = const [],
    this.resumePosition,
    this.monthProgress = const [],
  });

  List<RsBookStats> bookStats;
  Reference? resumePosition;
  List<DayProgress> monthProgress;

  bool queueStatsRequests = false;
  final statsRequests = <Completer<List<RsBookStats>>>[];
  final bookmarkedValues = <bool>[];

  @override
  Future<List<RsBookStats>> getBooksStats(int readingPlanId) {
    if (queueStatsRequests) {
      final request = Completer<List<RsBookStats>>();
      statsRequests.add(request);
      return request.future;
    }
    return Future.value(List.of(bookStats));
  }

  @override
  Future<Reference?> getResumeReference(int planId, {Reference? after}) async {
    return resumePosition ?? after;
  }

  @override
  Future<List<DayProgress>> getMonthProgress(
    int readingPlanId,
    DateTime month,
  ) async {
    return monthProgress;
  }

  @override
  Future<ReadingPlan> setReadingPlanBookmark(
    ReadingPlan readingPlan,
    bool isBookmarked,
  ) async {
    bookmarkedValues.add(isBookmarked);
    return readingPlan.copyWith(isBookmarked: isBookmarked);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingSessionViewModel sessionViewModel;

  setUp(() {
    sessionViewModel = FakeReadingSessionViewModel();
  });

  ReadingPlanDetailViewModel newViewModel(
    ReadingPlanDetails plan,
    FakeDetailPlanService service,
  ) {
    return ReadingPlanDetailViewModel.withDependencies(
      plan: plan,
      planService: service,
      sessionViewModel: sessionViewModel,
    );
  }

  Widget buildApp(Widget home) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Material(color: Theme.of(context).colorScheme.surface, child: child),
      home: home,
    );
  }

  Future<void> openDetail(
    WidgetTester tester,
    ReadingPlanDetailViewModel viewModel,
  ) async {
    await tester.pumpWidget(buildApp(_DetailLauncher(viewModel: viewModel)));
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('rendering', () {
    testWidgets('shows a loader until initialization finishes', (tester) async {
      final service = FakeDetailPlanService()..queueStatsRequests = true;
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      service.statsRequests.single.complete(bookStats());
      await tester.pumpAndSettle();

      expect(find.text('Ruth Plan'), findsOneWidget);
      expect(find.text('Start Reading'), findsOneWidget);
    });

    testWidgets('shows resume wording after reading has started', (
      tester,
    ) async {
      final service = FakeDetailPlanService(
        bookStats: bookStats(versesRead: 1),
      );
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('Resume Reading'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('back closes the detail panel', (tester) async {
      final service = FakeDetailPlanService(bookStats: bookStats());
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });

    testWidgets('starting a session closes every route above the root', (
      tester,
    ) async {
      final service = FakeDetailPlanService(bookStats: bookStats());
      final plan = planDetails(id: 7);
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Reading'));
      await tester.pumpAndSettle();

      expect(sessionViewModel.startedPlanIds, [7]);
      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });
  });

  group('bookmark', () {
    testWidgets('toggles the bookmark', (tester) async {
      final service = FakeDetailPlanService(bookStats: bookStats());
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(service.bookmarkedValues, [true]);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });
  });
}

class _DetailLauncher extends StatelessWidget {
  const _DetailLauncher({required this.viewModel});

  final ReadingPlanDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReadingPlanDetailPanel.withDependencies(
                  viewModel: viewModel,
                ),
              ),
            );
          },
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}

ReadingPlanDetails planDetails({int id = 1}) {
  return ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: 'Ruth Plan',
      createdAt: DateTime(2026, 1, 1),
      collectionId: 1,
      goalType: GoalType.verses.name,
      goalValue: 10,
      isBookmarked: false,
    ),
    [ReadingPlanBook(readingPlanId: id, bookId: 8, ord: 1)],
  );
}

List<RsBookStats> bookStats({int versesRead = 0}) {
  return [
    RsBookStats(
      bookId: 8,
      totalVerses: 85,
      versesRead: versesRead,
      lastRead: null,
    ),
  ];
}
