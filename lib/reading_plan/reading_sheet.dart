import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/reading_plan/reading_plan_panel.dart';
import 'package:gbt/reading_plan/reading_plan_panel_view_model.dart';

class ReadingSheet extends StatefulWidget {
  const ReadingSheet({super.key});

  @override
  State<ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<ReadingSheet> {
  ReadingPlanPanelViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlanPanel());
  }

  Future<void> _loadPlanPanel() async {
    final viewModel = await ReadingPlanPanelViewModel.create();
    if (!mounted) {
      viewModel.dispose();
      return;
    }

    setState(() {
      _viewModel = viewModel;
    });
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: ScaffoldMessenger(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      _handle(context),
                      const SizedBox(height: 16),
                      Expanded(child: _panel(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final viewModel = _viewModel;
    if (viewModel == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            Navigator.of(context).pop();
          },
          child: ReadingPlanPanel(viewModel: viewModel),
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
