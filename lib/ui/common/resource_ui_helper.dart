import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/download_progress_dialog.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

class ResourceUIHelper {
  static final Map<String, Future<bool>> _pendingRequests = {};

  final _resourceService = getIt<ResourceService>();
  final _messenger = getIt<MessengerViewModel>();

  Future<bool> ensureResource(
    BuildContext context,
    ResourceType resourceType,
    String id,
  ) {
    final key = '${resourceType.name}:$id';
    final pending = _pendingRequests[key];
    if (pending != null) return pending;

    final future = _ensureResource(context, resourceType, id).whenComplete(() {
      _pendingRequests.remove(key);
    });
    _pendingRequests[key] = future;
    return future;
  }

  Future<bool> _ensureResource(
    BuildContext context,
    ResourceType resourceType,
    String id,
  ) async {
    if (await _resourceService.resourceExists(resourceType, id)) {
      return true;
    }

    if (resourceType == ResourceType.gloss &&
        ResourceDownloadPromptDialog.glossDeclinedRecently(id)) {
      return false;
    }

    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context)!;

    // 1. Show Prompt
    final shouldDownload = await ResourceDownloadPromptDialog.show(context);

    if (!shouldDownload) {
      if (resourceType == ResourceType.gloss) {
        ResourceDownloadPromptDialog.markGlossDeclined(id);
      }
      return false;
    }

    // 2. Show Download Dialog
    try {
      if (!context.mounted) throw Exception('Context not mounted');
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, token) => _resourceService.downloadResource(
          resourceType,
          id,
          onProgress: (p) => progress.value = p,
          cancelToken: token,
        ),
      );
      return true;
    } catch (e) {
      if (e is! DownloadCanceledException) {
        _messenger.showError("${l10n.downloadFailed}: $e");
      }
      return false;
    }
  }
}

class ResourceDownloadPromptDialog extends StatelessWidget {
  const ResourceDownloadPromptDialog({super.key});

  static final Map<String, DateTime> _glossDeclinedAt = {};

  static const repromptDelay = Duration(hours: 1);

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  static bool glossDeclinedRecently(String langCode) {
    final declinedAt = _glossDeclinedAt[langCode];
    if (declinedAt == null) return false;
    return clock().difference(declinedAt) < repromptDelay;
  }

  static void markGlossDeclined(String langCode) {
    _glossDeclinedAt[langCode] = clock();
  }

  @visibleForTesting
  static void resetDeclineTracking() {
    _glossDeclinedAt.clear();
  }

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const ResourceDownloadPromptDialog(),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      content: Text(l10n.downloadResourcesMessage),
      actions: [
        TextButton(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context, false),
        ),
        FilledButton(
          child: Text(l10n.download),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
