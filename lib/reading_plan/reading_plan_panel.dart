import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/edit_reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_card.dart';
import 'package:gbt/reading_plan/reading_plan_detail_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';
import 'package:gbt/reading_plan/rs_model.dart';

class ReadingPlanPanel extends StatefulWidget {
  final VoidCallback onClose;

  const ReadingPlanPanel({super.key, required this.onClose});

  @override
  State<ReadingPlanPanel> createState() => ReadingPlanPanelState();
}

class ReadingPlanPanelState extends State<ReadingPlanPanel> {
  late final ReadingPlanPanelViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = ReadingPlanPanelViewModel();
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
        return SizedBox.expand(
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _handle(),
                  const SizedBox(height: 16),
                  _topTitle(),
                  const SizedBox(height: 12),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _handle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
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

  Widget _content() {
    if (!viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        if (viewModel.plans.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.noReadingPlans, textAlign: TextAlign.center),
                Text(
                  l10n.createYourFirstPlanBelow,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView(
            padding: const EdgeInsets.only(bottom: 76),
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
          ),
        Positioned(left: 0, right: 0, bottom: 0, child: _createNewPlanButton()),
      ],
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
              builder: (_) =>
                  EditReadingPlanPanel.newPlan(l10n.defaultReadingPlanName),
            ),
          );

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
        builder: (_) => ReadingPlanDetailPanel(
          readingPlanDetails: plan,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (!mounted) return;
    await viewModel.refresh();
  }

  Future<void> _editPlan(ReadingPlanDetails plan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditReadingPlanPanel.existing(plan)),
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
    widget.onClose();
  }
}
