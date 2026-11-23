import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/common/reference.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/reading_plan_card.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/reading_session_view_model.dart';
import 'package:gbt/reading_plan/progress_circle.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_reading_plan_service.dart';
import 'fake_reading_session_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeReadingPlanService planService;
  late FakeReadingSessionViewModel sessionViewModel;

  setUp(() {
    planService = FakeReadingPlanService();
    sessionViewModel = FakeReadingSessionViewModel();
  });

  Future<ReadingPlanPanelViewModel> createViewModel() {
    return ReadingPlanPanelViewModel.create(
      planService: planService,
      sessionViewModel: sessionViewModel,
    );
  }

  ReadingPlanPanel buildPanel({
    required ReadingPlanPanelViewModel viewModel,
    Future<void> Function(BuildContext context, String name)?
    navigateToCreatePlanRoute,
    Future<void> Function(BuildContext context, int planId)?
    navigateToPlanDetailsRoute,
    Future<void> Function(BuildContext context, int planId)?
    navigateToEditPlanRoute,
  }) {
    return ReadingPlanPanel.withDependencies(
      viewModel: viewModel,
      navigateToCreatePlanRoute: navigateToCreatePlanRoute,
      navigateToPlanDetailsRoute: navigateToPlanDetailsRoute,
      navigateToEditPlanRoute: navigateToEditPlanRoute,
    );
  }

  Widget buildApp({required Widget home}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Material(color: Theme.of(context).colorScheme.surface, child: child),
      home: home,
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    Future<void> Function(BuildContext context, String name)?
    navigateToCreatePlanRoute,
    Future<void> Function(BuildContext context, int planId)?
    navigateToPlanDetailsRoute,
    Future<void> Function(BuildContext context, int planId)?
    navigateToEditPlanRoute,
  }) async {
    final viewModel = await createViewModel();
    await tester.pumpWidget(
      buildApp(
        home: Scaffold(
          body: buildPanel(
            viewModel: viewModel,
            navigateToCreatePlanRoute: navigateToCreatePlanRoute,
            navigateToPlanDetailsRoute: navigateToPlanDetailsRoute,
            navigateToEditPlanRoute: navigateToEditPlanRoute,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('shows the empty state and create button without plans', (
      tester,
    ) async {
      await pumpPanel(tester);

      expect(find.text('No reading plans.'), findsOneWidget);
      expect(find.text('Create your first plan below.'), findsOneWidget);
      expect(find.text('Create New Plan'), findsOneWidget);
      expect(find.byType(ReadingPlanCard), findsNothing);
    });

    testWidgets('shows one card per plan', (tester) async {
      planService.plans = [
        planDetails('Ruth', id: 1),
        planDetails('Psalms', id: 2),
      ];

      await pumpPanel(tester);

      expect(find.byType(ReadingPlanCard), findsNWidgets(2));
      expect(find.text('Ruth'), findsOneWidget);
      expect(find.text('Psalms'), findsOneWidget);
    });
  });

  group('card overlays', () {
    final day = DateTime(2026, 11, 23);

    testWidgets('shows the bookmark ribbon only for bookmarked plans', (
      tester,
    ) async {
      planService.plans = [
        planDetails('Bookmarked', id: 1, isBookmarked: true),
        planDetails('Plain', id: 2),
      ];

      await pumpPanel(tester);

      expect(
        find.byKey(const ValueKey('plan-bookmark-ribbon-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-bookmark-ribbon-2')),
        findsNothing,
      );
    });

    testWidgets('shows the remaining verses for today', (tester) async {
      planService.plans = [
        planDetails(
          'Ruth',
          id: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          todayProgress: DayProgress(day, 0, 3, false),
        ),
      ];

      await pumpPanel(tester);

      expect(find.text('7 verses left today'), findsOneWidget);
    });

    testWidgets('shows the remaining minutes for today', (tester) async {
      planService.plans = [
        planDetails(
          'Ruth',
          id: 1,
          goalType: GoalType.minutes,
          goalValue: 30,
          todayProgress: DayProgress(day, 18, 0, false),
        ),
      ];

      await pumpPanel(tester);

      expect(find.text('12 minutes left today'), findsOneWidget);
    });

    testWidgets('shows a check and completion label when the goal is reached', (
      tester,
    ) async {
      planService.plans = [
        planDetails(
          'Ruth',
          id: 1,
          goalType: GoalType.verses,
          goalValue: 10,
          todayProgress: DayProgress(day, 0, 12, true),
        ),
      ];

      await pumpPanel(tester);

      final label = find.byKey(const ValueKey('plan-daily-goal-1'));
      expect(label, findsOneWidget);
      expect(find.text('Daily Goal Reached'), findsOneWidget);
      expect(
        find.descendant(of: label, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('shows overall progress circle and read over total verses', (
      tester,
    ) async {
      planService.plans = [
        planDetails(
          'Ruth',
          id: 1,
          totalVerses: 100,
          versesRead: 66,
          todayProgress: DayProgress(day, 0, 0, false),
        ),
      ];

      await pumpPanel(tester);

      final circle = tester.widget<ProgressCircle>(find.byType(ProgressCircle));
      expect(circle.percent, 0.66);
      expect(circle.size, 32);
      expect(find.text('66/100 verses'), findsOneWidget);
      expect(find.text('66/100 verses · 66%'), findsNothing);
    });
  });

  group('edit', () {
    testWidgets('create navigates and refreshes the list', (tester) async {
      final openedNames = <String>[];
      await pumpPanel(
        tester,
        navigateToCreatePlanRoute: (context, name) async {
          openedNames.add(name);
          planService.plans = [planDetails('New Plan', id: 2)];
        },
      );

      await tester.tap(find.text('Create New Plan'));
      await tester.pumpAndSettle();

      expect(openedNames, hasLength(1));
      expect(find.text('New Plan'), findsOneWidget);
    });

    testWidgets('edit navigates with the plan id and refreshes', (
      tester,
    ) async {
      final editedPlanIds = <int>[];
      planService.plans = [planDetails('Ruth', id: 1)];
      await pumpPanel(
        tester,
        navigateToEditPlanRoute: (context, planId) async {
          editedPlanIds.add(planId);
          planService.plans = [planDetails('Edited Ruth', id: 1)];
        },
      );

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(editedPlanIds, [1]);
      expect(find.text('Edited Ruth'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('delete asks for confirmation before removing the plan', (
      tester,
    ) async {
      planService.plans = [
        planDetails('Keep', id: 1),
        planDetails('Doomed', id: 2),
      ];
      await pumpPanel(tester);

      final doomedCard = find.widgetWithText(ReadingPlanCard, 'Doomed');
      final deleteButton = find.descendant(
        of: doomedCard,
        matching: find.byIcon(Icons.delete_outline_rounded),
      );

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Delete Reading Plan?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(planService.deletedPlanIds, isEmpty);
      expect(find.text('Doomed'), findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(planService.deletedPlanIds, [2]);
      expect(find.text('Doomed'), findsNothing);
      expect(find.text('Keep'), findsOneWidget);
    });
  });

  group('view plan', () {
    testWidgets('details navigation uses the plan id and refreshes', (
      tester,
    ) async {
      final openedPlanIds = <int>[];
      planService.plans = [planDetails('Ruth', id: 1)];
      await pumpPanel(
        tester,
        navigateToPlanDetailsRoute: (context, planId) async {
          openedPlanIds.add(planId);
          planService.plans = [planDetails('Renamed Ruth', id: 1)];
        },
      );

      await tester.tap(find.text('Ruth'));
      await tester.pumpAndSettle();

      expect(openedPlanIds, [1]);
      expect(find.text('Renamed Ruth'), findsOneWidget);
    });
  });

  group('view plan default route', () {
    tearDown(() async {
      await getIt.reset();
    });

    testWidgets('initializes the detail view model before navigating', (
      tester,
    ) async {
      planService.plans = [planDetails('Ruth', id: 1)];
      planService.queuePlanRequests = true;
      getIt.registerSingleton<ReadingPlanService>(planService);
      getIt.registerSingleton<ReadingSessionViewModel>(sessionViewModel);

      await pumpPanel(tester);
      await tester.tap(find.text('Ruth'));
      await tester.pump();

      expect(find.byType(ReadingPlanDetailPanel), findsNothing);
      expect(planService.planRequests, hasLength(1));

      planService.planRequests.single.complete(planService.plans.single);
      await tester.pumpAndSettle();

      expect(find.byType(ReadingPlanDetailPanel), findsOneWidget);
      expect(find.text('Ruth'), findsOneWidget);
    });
  });

  group('resume', () {
    testWidgets('resume starts the session and closes the panel', (
      tester,
    ) async {
      planService.plans = [
        planDetails(
          'Ruth',
          id: 7,
          resumePosition: const Reference(bookId: 8, chapter: 1, verse: 1),
        ),
      ];

      final viewModel = await createViewModel();
      await tester.pumpWidget(
        buildApp(home: _PanelLauncher(viewModel: viewModel)),
      );
      await tester.tap(find.text('Open plans'));
      await tester.pumpAndSettle();
      final resumeButton = find.byKey(const ValueKey('plan-resume-7'));
      expect(resumeButton, findsOneWidget);
      expect(
        find.descendant(of: resumeButton, matching: find.text('Ruth 1:1')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumeButton,
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );

      final buttonRect = tester.getRect(resumeButton);
      await tester.tapAt(Offset(buttonRect.center.dx, buttonRect.bottom - 2));
      await tester.pumpAndSettle();

      expect(sessionViewModel.startedPlanIds, [7]);
      expect(find.byType(ReadingPlanPanel), findsNothing);
      expect(find.text('Open plans'), findsOneWidget);
    });
  });
}

class _PanelLauncher extends StatelessWidget {
  const _PanelLauncher({required this.viewModel});

  final ReadingPlanPanelViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: ReadingPlanPanel.withDependencies(viewModel: viewModel),
                ),
              ),
            );
          },
          child: const Text('Open plans'),
        ),
      ),
    );
  }
}

ReadingPlanDetails planDetails(
  String name, {
  int? id = 1,
  int totalVerses = 0,
  int versesRead = 0,
  bool isBookmarked = false,
  GoalType goalType = GoalType.verses,
  int goalValue = 10,
  DayProgress? todayProgress,
  Reference? resumePosition,
}) {
  final details = ReadingPlanDetails(
    ReadingPlan(
      id: id,
      planName: name,
      createdAt: DateTime.now(),
      collectionId: 1,
      goalType: goalType.name,
      goalValue: goalValue,
      isBookmarked: isBookmarked,
    ),
    const [],
  );
  details.totalVerses = totalVerses;
  details.versesRead = versesRead;
  details.todayProgress = todayProgress;
  details.resumePosition = resumePosition;
  return details;
}
