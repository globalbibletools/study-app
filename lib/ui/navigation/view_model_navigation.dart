import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

Future<R?> pushInitializedPage<T, R>({
  required BuildContext context,
  required Future<T> Function() initialize,
  required Widget Function(T value) buildView,
  void Function(T value)? disposeIfAbandoned,
  String Function(AppLocalizations l10n)? loadErrorMessage,
  bool rootNavigator = false,
  bool fullscreenDialog = false,
  Future<R?> Function(BuildContext context, Widget page)? present,
}) async {
  final messengerViewModel = getIt<MessengerViewModel>();

  final T value;
  try {
    value = await initialize();
  } catch (_) {
    if (!context.mounted) return null;

    final l10n = AppLocalizations.of(context)!;
    messengerViewModel.showError(
      loadErrorMessage?.call(l10n) ?? l10n.errorLoadingContent,
    );
    return null;
  }

  if (!context.mounted) {
    disposeIfAbandoned?.call(value);
    return null;
  }

  try {
    if (present != null) {
      return await present(context, buildView(value));
    }

    return await Navigator.of(context, rootNavigator: rootNavigator).push<R>(
      MaterialPageRoute<R>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => buildView(value),
      ),
    );
  } catch (_) {
    disposeIfAbandoned?.call(value);
    rethrow;
  }
}

Future<R?> pushViewModelPage<VM extends ChangeNotifier, R>({
  required BuildContext context,
  required Future<VM> Function() create,
  required Widget Function(VM value) buildView,
  String Function(AppLocalizations l10n)? loadErrorMessage,
  bool rootNavigator = false,
  bool fullscreenDialog = false,
  Future<R?> Function(BuildContext context, Widget page)? present,
}) {
  return pushInitializedPage<VM, R>(
    context: context,
    initialize: create,
    buildView: buildView,
    disposeIfAbandoned: (viewModel) => viewModel.dispose(),
    loadErrorMessage: loadErrorMessage,
    rootNavigator: rootNavigator,
    fullscreenDialog: fullscreenDialog,
    present: present,
  );
}
