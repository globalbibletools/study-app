import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_plan_service.dart';
import 'fake_reading_session_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingSessionViewModel sessionViewModel;

  setUp(() {
    sessionViewModel = FakeReadingSessionViewModel();
  });

  ReadingPlanDetailViewModel newViewModel(
    ReadingPlanDetails plan,
    FakeReadingPlanService service,
  ) {
    service.plans = [plan];
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
    ReadingPlanDetailViewModel viewModel, {
    Widget Function(BuildContext context, ReadingPlanDetails plan)?
    editPlanBuilder,
    DayActivityLogNavigator? dayActivityLogNavigator,
  }) async {
    await tester.pumpWidget(
      buildApp(
        _DetailLauncher(
          viewModel: viewModel,
          editPlanBuilder: editPlanBuilder,
          dayActivityLogNavigator: dayActivityLogNavigator,
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('initial load', () {
    testWidgets('shows a loader, then the full detail content', (tester) async {
      final service = FakeReadingPlanService()..queueStatsRequests = true;
      final viewModel = newViewModel(planDetails(), service);

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

    testWidgets('shows an error when the plan cannot be loaded', (
      tester,
    ) async {
      final service = FakeReadingPlanService();
      final viewModel = newViewModel(planDetails(), service);
      service.plans = [];

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ReadingPlanDetailPanel));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);
    });
  });

  group("today's progress", () {
    testWidgets('shows verse and time progress toward a verse goal', (
      tester,
    ) async {
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('3/10 verses'), findsOneWidget);
      expect(find.text('7 minutes'), findsOneWidget);
      expect(find.text('30%'), findsNWidgets(2));
    });

    testWidgets('rounds minutes to the nearest tenth', (tester) async {
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7.46);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('7.5 minutes'), findsOneWidget);
    });

    testWidgets('omits the verse target for a minutes goal', (tester) async {
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = newViewModel(
        planDetails(goalType: GoalType.minutes, goalValue: 20),
        service,
      );

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('3 verses'), findsOneWidget);
      expect(find.text('7/20 minutes'), findsOneWidget);
      expect(find.text('35%'), findsNWidgets(2));
    });
  });

  group('bookmark', () {
    testWidgets('toggles the bookmark and updates the icon', (tester) async {
      final service = FakeReadingPlanService()..bookStats = bookStats();
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      expect(service.bookmarkedValues, [true]);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });
  });

  group('edit plan', () {
    testWidgets('opens the injected edit widget and refreshes on return', (
      tester,
    ) async {
      final service = FakeReadingPlanService()..bookStats = bookStats();
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(
        tester,
        viewModel,
        editPlanBuilder: (context, plan) => _FakeEditPlan(plan: plan),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Editing Ruth Plan'), findsOneWidget);

      service.plans = [planDetails(name: 'Renamed Plan')];
      await tester.tap(find.text('Close edit'));
      await tester.pumpAndSettle();

      expect(find.text('Renamed Plan'), findsOneWidget);
      expect(find.text('Editing Ruth Plan'), findsNothing);
    });
  });

  group('books list', () {
    testWidgets('renders books in order without reorder handles', (
      tester,
    ) async {
      final service = FakeReadingPlanService()..bookStats = bookStats();
      final viewModel = newViewModel(
        planDetails(bookIds: const [8, 20]),
        service,
      );

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('Ruth'), findsOneWidget);
      expect(find.text('Proverbs'), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(
        tester.getTopLeft(find.text('Ruth')).dy,
        lessThan(tester.getTopLeft(find.text('Proverbs')).dy),
      );
    });
  });

  group('session start', () {
    testWidgets('starts the session and closes the detail routes', (
      tester,
    ) async {
      final service = FakeReadingPlanService()..bookStats = bookStats();
      final viewModel = newViewModel(planDetails(id: 7), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start at Ruth 1:1'));
      await tester.pumpAndSettle();

      expect(sessionViewModel.startedPlanIds, [7]);
      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });

    testWidgets('shows resume wording once reading has started', (
      tester,
    ) async {
      final service = FakeReadingPlanService()
        ..bookStats = bookStats(versesRead: 1);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('Resume at Ruth 1:1'), findsOneWidget);
      expect(find.text('Start at Ruth 1:1'), findsNothing);
    });
  });

  group('month progress', () {
    testWidgets('navigates between months and requests their progress', (
      tester,
    ) async {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final nextMonth = DateTime(now.year, now.month + 1);
      final service = FakeReadingPlanService()..bookStats = bookStats();
      service.monthProgressByMonth[currentMonth] = const [];
      service.monthProgressByMonth[nextMonth] = const [];
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ReadingPlanDetailPanel));
      final localizations = MaterialLocalizations.of(context);

      expect(
        find.text(localizations.formatMonthYear(currentMonth)),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(service.requestedMonths.last, nextMonth);
      expect(
        find.text(localizations.formatMonthYear(nextMonth)),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(service.requestedMonths.last, currentMonth);
      expect(
        find.text(localizations.formatMonthYear(currentMonth)),
        findsOneWidget,
      );
    });

    testWidgets('shows checked days from the visible month progress', (
      tester,
    ) async {
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(
          verses: 3,
          minutes: 7,
          goalReached: true,
        );
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('day activity log', () {
    testWidgets('opens the injected log for a day with progress', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(
        tester,
        viewModel,
        dayActivityLogNavigator: (context, date) {
          return Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  AlertDialog(content: Text('Activity for ${date.day}')),
            ),
          );
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();

      expect(find.text('Activity for ${now.day}'), findsOneWidget);
    });

    testWidgets('delegates day log navigation to the injected navigator', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(
        tester,
        viewModel,
        dayActivityLogNavigator: (context, date) {
          return Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => Text('Activity page for ${date.day}'),
            ),
          );
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();

      expect(find.text('Activity page for ${now.day}'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('refreshes the detail when the day log returns', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(
        tester,
        viewModel,
        dayActivityLogNavigator: (context, date) {
          return Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (dialogContext) => AlertDialog(
                content: Text('Activity for ${date.day}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close log'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await tester.pumpAndSettle();

      final callsBefore = service.getPlanByIdCalls;
      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();
      expect(find.text('Activity for ${now.day}'), findsOneWidget);

      service.plans = [planDetails(name: 'Refreshed Plan')];
      await tester.tap(find.text('Close log'));
      await tester.pumpAndSettle();

      expect(find.text('Refreshed Plan'), findsOneWidget);
      expect(service.getPlanByIdCalls, greaterThan(callsBefore));
    });

    testWidgets('does not open the log for an empty day', (tester) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService()
        ..bookStats = bookStats()
        ..monthProgress = const [];
      final viewModel = newViewModel(planDetails(), service);
      var opened = false;

      await openDetail(
        tester,
        viewModel,
        dayActivityLogNavigator: (context, date) async {
          opened = true;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();

      expect(opened, isFalse);
    });
  });

  group('back navigation', () {
    testWidgets('closes the detail panel', (tester) async {
      final service = FakeReadingPlanService()..bookStats = bookStats();
      final viewModel = newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });
  });
}

class _DetailLauncher extends StatelessWidget {
  const _DetailLauncher({
    required this.viewModel,
    this.editPlanBuilder,
    this.dayActivityLogNavigator,
  });

  final ReadingPlanDetailViewModel viewModel;
  final Widget Function(BuildContext context, ReadingPlanDetails plan)?
  editPlanBuilder;
  final DayActivityLogNavigator? dayActivityLogNavigator;

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
                  editPlanBuilder: editPlanBuilder,
                  dayActivityLogNavigator: dayActivityLogNavigator,
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

class _FakeEditPlan extends StatelessWidget {
  const _FakeEditPlan({required this.plan});

  final ReadingPlanDetails plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editing ${plan.readingPlan.planName}')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close edit'),
        ),
      ),
    );
  }
}

ReadingPlanDetails planDetails({
  int id = 1,
  String name = 'Ruth Plan',
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  List<int> bookIds = const [8],
  Reference? resumePosition,
}) {
  final details = ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: name,
      createdAt: DateTime(2026, 1, 1),
      collectionId: 1,
      goalType: goalType.name,
      goalValue: goalValue,
      isBookmarked: false,
    ),
    [
      for (var i = 0; i < bookIds.length; i++)
        ReadingPlanBook(readingPlanId: id, bookId: bookIds[i], ord: i + 1),
    ],
  );
  details.resumePosition = resumePosition;
  return details;
}

List<DayProgress> currentMonthProgress({
  required int verses,
  required num minutes,
  bool goalReached = false,
}) {
  final now = DateTime.now();
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  return [
    for (int day = 1; day <= daysInMonth; day++)
      if (day == now.day)
        DayProgress(
          DateTime(now.year, now.month, day),
          minutes,
          verses,
          goalReached,
        )
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
