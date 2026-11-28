import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel.dart';
import 'package:gbt/reading_plan/ui/reading_plan_panel_view_model.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

typedef NavigateToReadingSheetRoute =
    Future<void> Function(BuildContext context);

class ReadingSheet extends StatelessWidget {
  final Widget child;

  const ReadingSheet({super.key, required this.child});

  static Future<void> navigateTo(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messengerViewModel = getIt<MessengerViewModel>();
    ReadingPlanPanelViewModel viewModel;
    try {
      viewModel = await ReadingPlanPanelViewModel.create();
    } catch (_) {
      messengerViewModel.showError(l10n.errorLoadingContent);
      return;
    }

    if (!context.mounted) {
      viewModel.dispose();
      return;
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) =>
            ReadingSheet(child: ReadingPlanPanel(viewModel: viewModel)),
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }
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
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _handle(context),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _panel(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            Navigator.of(context).pop();
          },
          child: child,
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
