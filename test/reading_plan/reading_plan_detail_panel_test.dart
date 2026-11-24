import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/reading_plan/reading_plan_read_models.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_detail_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_database.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_plan_read_models.dart';
import 'fake_reading_plan_service.dart';
import 'fake_reading_session_database.dart';
import 'fake_reading_session_view_model.dart';
import 'reading_plan_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingSessionViewModel sessionViewModel;
  late FakeReadingPlanReadModels readModels;

  setUp(() {
    sessionViewModel = FakeReadingSessionViewModel();
    readModels = FakeReadingPlanReadModels();
  });

  Future<ReadingPlanDetailViewModel> newViewModel(
    ReadingPlanSummary plan,
    FakeReadingPlanService service,
  ) {
    readModels.plans = [plan];
    service.plans = [plan];
    return ReadingPlanDetailViewModel.create(
      planId: plan.planId,
      readModels: readModels,
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
    NavigateToExistingReadingPlanRoute? navigateToEditPlanRoute,
    NavigateToDayActivityLogRoute? navigateToDayActivityLogRoute,
  }) async {
    await tester.pumpWidget(
      buildApp(
        _DetailLauncher(
          viewModel: viewModel,
          navigateToEditPlanRoute: navigateToEditPlanRoute,
          navigateToDayActivityLogRoute: navigateToDayActivityLogRoute,
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('navigation helper', () {
    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('initializes the view model before navigating', (tester) async {
      final service = FakeReadingPlanService();
      final session = FakeReadingSessionViewModel();
      final summary = planDetails();
      readModels.plans = [summary];
      readModels.queueSummaryRequests = true;
      getIt.registerSingleton<ReadingPlanService>(service);
      getIt.registerSingleton<ReadingSessionViewModel>(session);
      getIt.registerSingleton<ReadingSessionDatabase>(
        FakeReadingSessionDatabase(readModels),
      );

      await tester.pumpWidget(
        buildApp(const _NavigateToDetailLauncher(planId: 1)),
      );
      await tester.tap(find.text('Open detail'));
      await tester.pump();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(readModels.summaryRequests, hasLength(1));

      readModels.summaryRequests.single.complete(summary);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsOneWidget);
      expect(find.text('Ruth Plan'), findsOneWidget);
    });

    testWidgets('shows an error and stays closed when loading fails', (
      tester,
    ) async {
      final service = FakeReadingPlanService();
      final session = FakeReadingSessionViewModel();
      readModels.plans = [];
      getIt.registerSingleton<ReadingPlanService>(service);
      getIt.registerSingleton<ReadingSessionViewModel>(session);
      getIt.registerSingleton<ReadingSessionDatabase>(
        FakeReadingSessionDatabase(readModels),
      );

      await tester.pumpWidget(
        buildApp(const _NavigateToDetailLauncher(planId: 1)),
      );
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);

      final context = tester.element(find.text('Open detail'));
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.errorLoadingContent), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('shows the full detail content after loading', (tester) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('Ruth Plan'), findsOneWidget);
      expect(find.text('Start at Ruth 1:1'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('Total Progress'), findsOneWidget);
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.textContaining('days remaining'), findsOneWidget);
    });
  });

  group("today's progress", () {
    testWidgets('shows verse and time progress toward a verse goal', (
      tester,
    ) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = await newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('3/10 verses'), findsOneWidget);
      expect(find.text('7 minutes'), findsOneWidget);
      expect(find.text('30%'), findsNWidgets(2));
    });

    testWidgets('rounds minutes to the nearest tenth', (tester) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7.46);
      final viewModel = await newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.text('7.5 minutes'), findsOneWidget);
    });

    testWidgets('omits the verse target for a minutes goal', (tester) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = await newViewModel(
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
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(planDetails(), service);

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
    testWidgets('navigates with the plan id and refreshes', (tester) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(planDetails(), service);
      final editedPlanIds = <int>[];

      await openDetail(
        tester,
        viewModel,
        navigateToEditPlanRoute: (context, planId) async {
          editedPlanIds.add(planId);
          readModels.plans = [planDetails(name: 'Renamed Plan')];
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(editedPlanIds, [1]);
      expect(find.text('Renamed Plan'), findsOneWidget);
    });
  });

  group('books list', () {
    testWidgets('renders books in order without reorder handles', (
      tester,
    ) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(
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
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(planDetails(id: 7), service);

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
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats(versesRead: 1);
      final viewModel = await newViewModel(planDetails(), service);

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
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgressByMonth[currentMonth] = const [];
      readModels.monthProgressByMonth[nextMonth] = const [];
      final viewModel = await newViewModel(planDetails(), service);

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

      expect(readModels.requestedMonths.last, nextMonth);
      expect(
        find.text(localizations.formatMonthYear(nextMonth)),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(readModels.requestedMonths.last, currentMonth);
      expect(
        find.text(localizations.formatMonthYear(currentMonth)),
        findsOneWidget,
      );
    });

    testWidgets('shows checked days from the visible month progress', (
      tester,
    ) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(
        verses: 3,
        minutes: 7,
        goalReached: true,
      );
      final viewModel = await newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('day activity log', () {
    testWidgets('navigates with the day and plan id', (tester) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = await newViewModel(planDetails(), service);
      DateTime? openedDate;
      int? openedPlanId;

      await openDetail(
        tester,
        viewModel,
        navigateToDayActivityLogRoute:
            (context, date, {required int readingPlanId}) async {
              openedDate = date;
              openedPlanId = readingPlanId;
            },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();

      expect(openedDate, DateTime(now.year, now.month, now.day));
      expect(openedPlanId, 1);
    });

    testWidgets('opens the log for an empty day', (tester) async {
      final now = DateTime.now();
      final emptyDay = now.day == 1 ? 2 : 1;
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = const [];
      final viewModel = await newViewModel(planDetails(), service);
      DateTime? openedDate;

      await openDetail(
        tester,
        viewModel,
        navigateToDayActivityLogRoute:
            (context, date, {required int readingPlanId}) async {
              openedDate = date;
            },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('calendar-day-$emptyDay')));
      await tester.pumpAndSettle();

      expect(openedDate, DateTime(now.year, now.month, emptyDay));
    });

    testWidgets('opens the log for every rendered day in the visible month', (
      tester,
    ) async {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = const [];
      final viewModel = await newViewModel(planDetails(), service);
      final openedDates = <DateTime>[];

      await openDetail(
        tester,
        viewModel,
        navigateToDayActivityLogRoute:
            (context, date, {required int readingPlanId}) async {
              openedDates.add(date);
            },
      );
      await tester.pumpAndSettle();

      for (var day = 1; day <= daysInMonth; day++) {
        final dayFinder = find.byKey(ValueKey('calendar-day-$day'));
        await tester.ensureVisible(dayFinder);
        await tester.pumpAndSettle();
        await tester.tap(dayFinder);
        await tester.pumpAndSettle();
      }

      expect(openedDates, [
        for (var day = 1; day <= daysInMonth; day++)
          DateTime(now.year, now.month, day),
      ]);
    });

    testWidgets('delegates day log navigation to the injected navigator', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = await newViewModel(planDetails(), service);
      DateTime? openedDate;

      await openDetail(
        tester,
        viewModel,
        navigateToDayActivityLogRoute:
            (context, date, {required int readingPlanId}) {
              openedDate = date;
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

      expect(openedDate, DateTime(now.year, now.month, now.day));
      expect(find.text('Activity page for ${now.day}'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('refreshes the detail when the day log returns', (
      tester,
    ) async {
      final now = DateTime.now();
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      readModels.monthProgress = currentMonthProgress(verses: 3, minutes: 7);
      final viewModel = await newViewModel(planDetails(), service);
      DateTime? openedDate;

      await openDetail(
        tester,
        viewModel,
        navigateToDayActivityLogRoute:
            (context, date, {required int readingPlanId}) {
              openedDate = date;
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

      final callsBefore = readModels.summaryCalls;
      await tester.tap(find.text('${now.day}'));
      await tester.pumpAndSettle();
      expect(openedDate, DateTime(now.year, now.month, now.day));
      expect(find.text('Activity for ${now.day}'), findsOneWidget);

      readModels.plans = [planDetails(name: 'Refreshed Plan')];
      await tester.tap(find.text('Close log'));
      await tester.pumpAndSettle();

      expect(find.text('Refreshed Plan'), findsOneWidget);
      expect(readModels.summaryCalls, greaterThan(callsBefore));
    });
  });

  group('back navigation', () {
    testWidgets('closes the detail panel', (tester) async {
      final service = FakeReadingPlanService();
      readModels.bookStats = bookStats();
      final viewModel = await newViewModel(planDetails(), service);

      await openDetail(tester, viewModel);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(find.text('Open detail'), findsOneWidget);
    });
  });
}

class _NavigateToDetailLauncher extends StatelessWidget {
  const _NavigateToDetailLauncher({required this.planId});

  final int planId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => ReadingPlanDetailPanel.navigateTo(context, planId),
          child: const Text('Open detail'),
        ),
      ),
    );
  }
}

class _DetailLauncher extends StatelessWidget {
  const _DetailLauncher({
    required this.viewModel,
    this.navigateToEditPlanRoute,
    this.navigateToDayActivityLogRoute,
  });

  final ReadingPlanDetailViewModel viewModel;
  final NavigateToExistingReadingPlanRoute? navigateToEditPlanRoute;
  final NavigateToDayActivityLogRoute? navigateToDayActivityLogRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReadingPlanDetailPanel(
                  viewModel: viewModel,
                  navigateToEditPlanRoute: navigateToEditPlanRoute,
                  navigateToDayActivityLogRoute: navigateToDayActivityLogRoute,
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

ReadingPlanSummary planDetails({
  int id = 1,
  String name = 'Ruth Plan',
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  List<int> bookIds = const [8],
  Reference? resumePosition,
}) {
  return planSummary(
    id: id,
    name: name,
    goalType: goalType,
    goalValue: goalValue,
    bookIds: bookIds,
    resumePosition: resumePosition,
  );
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
        DayProgress.minutes(
          DateTime(now.year, now.month, day),
          minutes,
          verses,
          goalReached,
        )
      else
        DayProgress.empty(DateTime(now.year, now.month, day)),
  ];
}

List<BookProgress> bookStats({int versesRead = 0}) {
  return [BookProgress(bookId: 8, totalVerses: 85, versesRead: versesRead)];
}
