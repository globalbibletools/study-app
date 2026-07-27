import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/download_progress_dialog.dart';

/// Collapsing Glosses section shown on the download manager page.
///
/// Lists each available gloss resource from the resource manager and exposes
/// a download button that triggers the resource manager's download function.
class GlossesSection extends StatefulWidget {
  const GlossesSection({super.key});

  @override
  State<GlossesSection> createState() => _GlossesSectionState();
}

class _GlossesSectionState extends State<GlossesSection> {
  final _resourceService = getIt<ResourceService>();
  List<ResourceView> _resources = [];

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final resources =
        await _resourceService.getResourcesByType(ResourceType.Gloss);
    if (!mounted) return;
    setState(() => _resources = resources);
  }

  Future<void> _reload() async {
    _loadResources();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ExpansionTile(
      key: const PageStorageKey('glosses_section_main'),
      leading: const Icon(Icons.translate),
      title: Text(l10n.glosses),
      initiallyExpanded: false,
      children: _resources
        .map(
          (resource) => _GlossDownloadTile(
            key: ValueKey('gloss_${resource.id}'),
            resource: resource,
            onChanged: _reload,
          ),
        )
        .toList(),
    );
  }
}

class _GlossDownloadTile extends StatefulWidget {
  final ResourceView resource;
  final VoidCallback onChanged;

  const _GlossDownloadTile({
    super.key,
    required this.resource,
    required this.onChanged,
  });

  @override
  State<_GlossDownloadTile> createState() => _GlossDownloadTileState();
}

class _GlossDownloadTileState extends State<_GlossDownloadTile> {
  final _resourceService = getIt<ResourceService>();
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          await _resourceService.downloadResource(
            ResourceType.Gloss,
            widget.resource.id,
            onProgress: (p) => progress.value = p,
            cancelToken: cancelToken,
          );
        },
      );
    } catch (e) {
      if (mounted && e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onChanged();
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await _resourceService.deleteResource(
        ResourceType.Gloss,
        widget.resource.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final isInstalled = widget.resource.installState == InstallState.Installed;
    final needsUpdate = isInstalled &&
        widget.resource.localUpdatedAt != widget.resource.serverUpdatedAt;

    Widget trailing;
    if (needsUpdate) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: primaryColor,
            onPressed: _busy ? null : _download,
            tooltip: l10n.download,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: primaryColor,
            onPressed: _busy ? null : _delete,
            tooltip: l10n.delete,
          ),
        ],
      );
    } else {
      trailing = IconButton(
        icon: Icon(isInstalled ? Icons.delete : Icons.download),
        color: primaryColor,
        onPressed: _busy ? null : (isInstalled ? _delete : _download),
        tooltip: isInstalled ? l10n.delete : l10n.download,
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(widget.resource.resourceName),
      trailing: trailing,
    );
  }
}
