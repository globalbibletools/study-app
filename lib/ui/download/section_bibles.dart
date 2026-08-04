import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/download_progress_dialog.dart';

/// Collapsing Bibles section shown on the download manager page.
///
/// Lists each available bible resource from the resource manager and exposes
/// a download button that triggers the resource manager's download function.
class BiblesSection extends StatefulWidget {
  const BiblesSection({super.key});

  @override
  State<BiblesSection> createState() => _BiblesSectionState();
}

class _BiblesSectionState extends State<BiblesSection> {
  final _resourceService = getIt<ResourceService>();
  List<ResourceView> _resources = [];

  @override
  void initState() {
    super.initState();
    _resourceService.addResourceChangeListener(
      ResourceType.bible,
      _onResourcesChanged,
    );
    _loadResources();
  }

  @override
  void dispose() {
    _resourceService.removeResourceChangeListener(
      ResourceType.bible,
      _onResourcesChanged,
    );
    super.dispose();
  }

  void _onResourcesChanged(ResourceType type) {
    _loadResources();
  }

  Future<void> _loadResources() async {
    final resources =
        await _resourceService.getResourcesByType(ResourceType.bible);
    if (!mounted) return;
    setState(() => _resources = resources);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ExpansionTile(
      key: const PageStorageKey('bibles_section_main'),
      leading: ValueListenableBuilder<OutdatedResourceCounts>(
        valueListenable: _resourceService.outdatedResourceCounts,
        builder: (context, counts, _) {
          return Badge.count(
            count: counts.of(ResourceType.bible),
            isLabelVisible: counts.of(ResourceType.bible) > 0,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.book),
          );
        },
      ),
      title: Text(l10n.bibles),
      initiallyExpanded: false,
      children: _resources
        .map(
          (resource) => _BibleDownloadTile(
            key: ValueKey('bible_${resource.id}'),
            resource: resource,
          ),
        )
        .toList(),
    );
  }
}

class _BibleDownloadTile extends StatefulWidget {
  final ResourceView resource;

  const _BibleDownloadTile({
    super.key,
    required this.resource,
  });

  @override
  State<_BibleDownloadTile> createState() => _BibleDownloadTileState();
}

class _BibleDownloadTileState extends State<_BibleDownloadTile> {
  final _resourceService = getIt<ResourceService>();
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          await _resourceService.downloadResource(
            ResourceType.bible,
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
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await _resourceService.deleteResource(
        ResourceType.bible,
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
