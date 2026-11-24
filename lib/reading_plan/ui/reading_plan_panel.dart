import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/ui/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_app_bar.dart';
import 'package:gbt/reading_plan/ui/reading_plan_card.dart';
import 'package:gbt/reading_plan/ui/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/data_access/rs_model.dart';

class ReadingPlanPanel extends StatefulWidget {
  const ReadingPlanPanel({
    super.key,
    required this.viewModel,
    this.navigateToCreatePlanRoute,
    this.navigateToPlanDetailsRoute,
    this.navigateToEditPlanRoute,
  });

  const ReadingPlanPanel.withDependencies({
    super.key,
    required this.viewModel,
    this.navigateToCreatePlanRoute,
    this.navigateToPlanDetailsRoute,
    this.navigateToEditPlanRoute,
  });

  final ReadingPlanPanelViewModel viewModel;
  final NavigateToNewReadingPlanRoute? navigateToCreatePlanRoute;
  final NavigateToReadingPlanDetailRoute? navigateToPlanDetailsRoute;
  final NavigateToExistingReadingPlanRoute? navigateToEditPlanRoute;

  @override
  ReadingPlanPanelState createState() => ReadingPlanPanelState();
}

class ReadingPlanPanelState extends State<ReadingPlanPanel> {
  late final ReadingPlanPanelViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            ReadingPlanAppBar(
              title: Text(l10n.readingPlans),
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  spacing: 16,
                  children: [
                    Expanded(child: _planList()),
                    _createNewPlanButton(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _planList() {
    final l10n = AppLocalizations.of(context)!;
    if (viewModel.plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.noReadingPlans, textAlign: TextAlign.center),
            Text(l10n.createYourFirstPlanBelow, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: viewModel.plans
          .map(
            (plan) => ReadingPlanCard(
              plan: plan,
              onOpenDetails: () => _openPlanDetails(plan),
              onEdit: () => _editPlan(plan),
              onStartSession: () => _startReadingSession(plan),
            ),
          )
          .toList(),
    );
  }

  Widget _createNewPlanButton() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () => _createNewPlan(l10n.defaultReadingPlanName),
        child: Text(
          l10n.createNewPlan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _createNewPlan(String defaultName) async {
    final navigate =
        widget.navigateToCreatePlanRoute ?? EditReadingPlanPanel.navigateToNew;
    await navigate(context, defaultName);

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _openPlanDetails(ReadingPlanDetails plan) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    final navigate =
        widget.navigateToPlanDetailsRoute ?? ReadingPlanDetailPanel.navigateTo;
    await navigate(context, planId);

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _editPlan(ReadingPlanDetails plan) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    final navigate =
        widget.navigateToEditPlanRoute ??
        EditReadingPlanPanel.navigateToExisting;
    await navigate(context, planId);

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _startReadingSession(ReadingPlanDetails plan) async {
    await viewModel.startReadingSession(plan);

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
