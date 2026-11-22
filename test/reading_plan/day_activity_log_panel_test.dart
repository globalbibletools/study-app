import 'package:flutter_test/flutter_test.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/day_activity_log_panel.dart';
import 'package:gbt/reading_plan/day_activity_log_view_model.dart';
import 'package:gbt/reading_plan/reading_plan_service.dart';
import 'package:gbt/reading_plan/rs_model.dart';
import 'package:material_ui/material_ui.dart';

class _ActivityLogPlanService extends Fake implements ReadingPlanService {
  _ActivityLogPlanService(this.sessions);

  final List<SessionDetails> sessions;

  @override
  Future<List<SessionDetails>> getDetailedProgressFor(
    DateTime date,
    int readingPlanId,
  ) async {
    return sessions;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders an injected initialized view model', (tester) async {
    final date = DateTime(2026, 11, 17);
    final sessions = [
      SessionDetails(
        RsSession(
          rsDate: date,
          startTime: DateTime(2026, 11, 17, 9, 5),
          readSeconds: 90,
          verses: 3,
          readingPlanId: 1,
        ),
        [DetailedProgess(63, 1, 1, 2), DetailedProgess(63, 1, 4, 4)],
      ),
    ];
    final viewModel = DayActivityLogViewModel.withDependencies(
      readingPlanId: 1,
      date: date,
      planService: _ActivityLogPlanService(sessions),
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DayActivityLogPanel(viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('1.5 min • 3 verses'), findsOneWidget);
    expect(find.text('2 John 1:1-2, 2 John 1:4'), findsOneWidget);
    expect(find.text('1.5 min'), findsOneWidget);
    expect(find.text('3 verses'), findsOneWidget);
  });
}
