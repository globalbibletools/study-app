import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/download_progress_dialog.dart';

class ResourceUIHelper {
  static final Map<String, Future<bool>> _pendingRequests = {};

  static Future<bool> ensureResource(
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

  static Future<bool> _ensureResource(
    BuildContext context,
    ResourceType resourceType,
    String id,
  ) async {
    final resourceService = getIt<ResourceService>();
    if (await resourceService.resourceExists(resourceType, id)) {
      return true;
    }

    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context)!;

    // 1. Show Prompt
    final shouldDownload =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
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
          ),
        ) ??
        false;

    if (!shouldDownload) return false;

    // 2. Show Download Dialog
    try {
      if (!context.mounted) throw Exception('Context not mounted');
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, token) => resourceService.downloadResource(
          resourceType,
          id,
          onProgress: (p) => progress.value = p,
          cancelToken: token,
        ),
      );
      return true;
    } catch (e) {
      if (context.mounted && e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("${l10n.downloadFailed}: $e")));
      }
      return false;
    }
  }
}
