import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/settings/reader_settings_panel.dart';
import 'package:gbt/ui/home/settings/reader_settings_view_model.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

/// Bottom sheet holding the reader-facing settings: the parallel-Bible
/// toggle, gloss language, Bible translation, verse layout, and font sizes.
///
/// Follows the [ReadingSheet] pattern: [navigateTo] constructs the view
/// model, shows the sheet, and the panel disposes the view model when the
/// sheet closes.
class ReaderSettingsSheet extends StatelessWidget {
  final Widget child;

  const ReaderSettingsSheet({super.key, required this.child});

  static Future<void> navigateTo(
    BuildContext context, {
    VoidCallback? onChanged,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messengerViewModel = getIt<MessengerViewModel>();
    ReaderSettingsViewModel viewModel;
    try {
      viewModel = await ReaderSettingsViewModel.create();
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
        builder: (context) => ReaderSettingsSheet(
          child: ReaderSettingsPanel(viewModel: viewModel),
        ),
      );
    } catch (_) {
      viewModel.dispose();
      rethrow;
    }

    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
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
                  Expanded(child: child),
                ],
              ),
            ),
          ),
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
