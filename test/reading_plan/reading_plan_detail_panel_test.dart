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
  ReadingPlanDetails? plan;

  bool queueStatsRequests = false;
  final statsRequests = <Completer<List<RsBookStats>>>[];
  final bookmarkedValues = <bool>[];

  @override
  Future<ReadingPlanDetails?> getReadingPlanById(int planId) async => plan;

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
  Future<Reference?> getResumeReference(int planId) async {
    return resumePosition;
  }

  @override
  Future<DayProgress> getDayProgress(int readingPlanId, DateTime date) async {
    for (final progress in monthProgress) {
      if (progress.day.year == date.year &&
          progress.day.month == date.month &&
          progress.day.day == date.day) {
        return progress;
      }
    }
    return DayProgress.empty(date);
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
    service.plan = plan;
    return ReadingPlanDetailViewModel.withDependencies(
      planId: plan.readingPlan.id!,
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
      expect(find.text('Start at Ruth 1:1'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('Total Progress'), findsOneWidget);
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.textContaining('days remaining'), findsOneWidget);
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

      expect(find.text('Resume at Ruth 1:1'), findsOneWidget);
    });

    testWidgets('shows verse and time progress with the applicable target', (
      tester,
    ) async {
      final service = FakeDetailPlanService(
        bookStats: bookStats(),
        monthProgress: currentMonthProgress(verses: 3, minutes: 7),
      );
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('3/10 verses'), findsOneWidget);
      expect(find.text('7 minutes'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
    });

    testWidgets('omits the target for the non-goal reading unit', (
      tester,
    ) async {
      final service = FakeDetailPlanService(
        bookStats: bookStats(),
        monthProgress: currentMonthProgress(verses: 3, minutes: 7),
      );
      final plan = planDetails(goalType: GoalType.minutes, goalValue: 20);
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('3 verses'), findsOneWidget);
      expect(find.text('7/20 minutes'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
    });

    testWidgets('shows a drag handle instead of an edit-order toggle', (
      tester,
    ) async {
      final service = FakeDetailPlanService(bookStats: bookStats());
      final plan = planDetails();
      final viewModel = newViewModel(plan, service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle_rounded), findsOneWidget);
      expect(find.text('Edit Order'), findsNothing);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.drag_handle_rounded),
          matching: find.byType(ReorderableDragStartListener),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Ruth'),
          matching: find.byType(ReorderableDragStartListener),
        ),
        findsNothing,
      );
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

      await tester.tap(find.text('Start at Ruth 1:1'));
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

ReadingPlanDetails planDetails({
  int id = 1,
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
}) {
  return ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: 'Ruth Plan',
      createdAt: DateTime(2026, 1, 1),
      collectionId: 1,
      goalType: goalType.name,
      goalValue: goalValue,
      isBookmarked: false,
    ),
    [ReadingPlanBook(readingPlanId: id, bookId: 8, ord: 1)],
  );
}

List<DayProgress> currentMonthProgress({
  required int verses,
  required int minutes,
}) {
  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  return [
    for (int day = 1; day <= daysInMonth; day++)
      if (day == now.day)
        DayProgress(DateTime(now.year, now.month, day), minutes, verses, false)
      else
        DayProgress.empty(DateTime(now.year, now.month, day)),
  ];
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
