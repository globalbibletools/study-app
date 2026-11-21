import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_card.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

typedef ReadingPlanRouteBuilder =
    Widget Function(BuildContext context, ReadingPlanDetails plan);

class ReadingPlanPanel extends StatefulWidget {
  const ReadingPlanPanel({
    super.key,
    this.viewModel,
    this.createPlanRouteBuilder,
    this.planDetailsRouteBuilder,
    this.editPlanRouteBuilder,
  });

  const ReadingPlanPanel.withDependencies({
    super.key,
    required this.viewModel,
    this.createPlanRouteBuilder,
    this.planDetailsRouteBuilder,
    this.editPlanRouteBuilder,
  });

  final ReadingPlanPanelViewModel? viewModel;
  final WidgetBuilder? createPlanRouteBuilder;
  final ReadingPlanRouteBuilder? planDetailsRouteBuilder;
  final ReadingPlanRouteBuilder? editPlanRouteBuilder;

  @override
  ReadingPlanPanelState createState() => ReadingPlanPanelState();
}

class ReadingPlanPanelState extends State<ReadingPlanPanel> {
  late final ReadingPlanPanelViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel ?? ReadingPlanPanelViewModel();
    unawaited(viewModel.initialize());
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
        return Column(
          spacing: 16,
          children: [
            _topTitle(),
            Expanded(
              child: Column(
                spacing: 16,
                children: [
                  Expanded(child: _planList()),
                  _createNewPlanButton(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topTitle() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.readingPlans,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _planList() {
    if (!viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

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
      children: viewModel.plans
          .map(
            (plan) => ReadingPlanCard(
              plan: plan,
              onOpenDetails: () => _openPlanDetails(plan),
              onEdit: () => _editPlan(plan),
              onDelete: () => _deletePlan(plan),
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
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  widget.createPlanRouteBuilder ??
                  (_) =>
                      EditReadingPlanPanel.newPlan(l10n.defaultReadingPlanName),
            ),
          );

          if (!mounted) return;
          await viewModel.refresh();
        },
        child: Text(
          l10n.createNewPlan,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _openPlanDetails(ReadingPlanDetails plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            widget.planDetailsRouteBuilder?.call(context, plan) ??
            ReadingPlanDetailPanel(planId: plan.readingPlan.id!),
      ),
    );

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _editPlan(ReadingPlanDetails plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            widget.editPlanRouteBuilder?.call(context, plan) ??
            EditReadingPlanPanel.existing(plan),
      ),
    );

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _deletePlan(ReadingPlanDetails plan) async {
    final planId = plan.readingPlan.id;
    if (planId == null) return;

    await viewModel.deletePlan(planId);
  }

  Future<void> _startReadingSession(ReadingPlanDetails plan) async {
    await viewModel.startReadingSession(plan);

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
