import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/download/cancel_token.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/common/download_progress_dialog.dart';


class ResourceSection extends StatefulWidget {
  final ResourceType resourceType;
  final String title;
  final IconData icon;

  const ResourceSection({
      super.key,
      required this.resourceType,
      required this.title,
      required this.icon,
  });

  @override
  State<ResourceSection> createState() => _ResourceSectionState();
}

class _ResourceSectionState extends State<ResourceSection> {
  final _resourceService = getIt<ResourceService>();
  List<ResourceTreeNode> _resources = [];
  int _descendantStaleCount = 0;

  @override
  void initState() {
    super.initState();
    _resourceService.addResourceTypeChangeListener(
      widget.resourceType,
      _onResourcesChanged,
    );
    _loadResources();
  }

  @override
  void dispose() {
    _resourceService.removeResourceTypeChangeListener(
      widget.resourceType,
      _onResourcesChanged,
    );
    super.dispose();
  }

  void _onResourcesChanged(ResourceType type) {
      if (type != widget.resourceType) return;

      _loadResources();
  }

  Future<void> _loadResources() async {
    final resources =
        await _resourceService.getResourcesByType(widget.resourceType);
    if (!mounted) return;
    setState(() {
        _resources = ResourceTreeNode.buildTree(resources);
        _descendantStaleCount = _resources.fold(0, (count, child) => count + child.descendantStaleCount + (child.needsUpdate ? 1 : 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey('section_${widget.resourceType.name}'),
      controlAffinity: ListTileControlAffinity.leading,
      shape: Border(),
      collapsedShape: Border(),
      title: Text.rich(
        TextSpan(
            children: [
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 3),
                        child: Icon(widget.icon, size: 16),
                    )
                ),
                TextSpan(text: widget.title),
                if (_descendantStaleCount > 0)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 3),
                        child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '$_descendantStaleCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                        ),
                    )
                ),
            ]
        )
      ),
      children: [
        _ResourceGroup(
            resourceType: widget.resourceType, 
            resources: _resources,
        )
      ],
    );
  }
}

class _ResourceGroup extends StatelessWidget {
  const _ResourceGroup({
    required this.resources,
    required this.resourceType,
  });

  final List<ResourceTreeNode> resources;
  final ResourceType resourceType;

  @override
  Widget build(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(left: 16),
        child: Column(
            children: resources
                .map(
                  (resource) => _DownloadTile(
                    key: ValueKey('${resourceType.name}_${resource.id}'),
                    resource: resource,
                    resourceType: resourceType,
                  ),
                )
                .toList()
        )
      );
  }
}

class _DownloadTile extends StatefulWidget {
  final ResourceTreeNode resource;
  final ResourceType resourceType;

  const _DownloadTile({
    super.key,
    required this.resourceType,
    required this.resource,
  });

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile> {
  final _resourceService = getIt<ResourceService>();
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          await _resourceService.downloadResource(
            widget.resourceType,
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
        widget.resourceType,
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

    Widget trailing;
    if (widget.resource.needsUpdate) {
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
        icon: Icon(widget.resource.isInstalled ? Icons.delete : Icons.download),
        color: primaryColor,
        onPressed: _busy ? null : (widget.resource.isInstalled ? _delete : _download),
        tooltip: widget.resource.isInstalled ? l10n.delete : l10n.download,
      );
    }

    if (widget.resource.children.isEmpty) {
        return ListTile(
          title: Text(widget.resource.resourceName),
          trailing: trailing,
        );
    } else {
        final nestedCount = widget.resource.descendantStaleCount;
        return ExpansionTile(
          key: PageStorageKey('section_${widget.resourceType.name}_${widget.resource.id}'),
          title: Text.rich(
            TextSpan(children: [
              TextSpan(text: widget.resource.resourceName),
              if (nestedCount > 0)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 3),
                        child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '$nestedCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                        ),
                    )
                )
            ]),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          shape: Border(),
          collapsedShape: Border(),
          children: [
            _ResourceGroup(
                resourceType: widget.resourceType, 
                resources: widget.resource.children,
            )
          ],
        );
    }
  }
}

class ResourceTreeNode {
    final String id;
    final String resourceName;
    final bool isInstalled;
    final bool needsUpdate;
    final int descendantStaleCount;
    final List<ResourceTreeNode> children;

    ResourceTreeNode({
        required this.id,
        required this.resourceName,
        required this.isInstalled,
        required this.needsUpdate,
        this.descendantStaleCount = 0,
        this.children = const [],
    });

    static List<ResourceTreeNode> buildTree(List<Resource> resourceList) {
        Map<int, Map<String, List<Resource>>> parentMap = {};

        for (final resource in resourceList) {
            var depth = 0;
            var lastIndex = 0;
            for (var i = 0; i < resource.id.length; i++) {
                if (resource.id[i] == '/') {
                    depth += 1;
                    lastIndex = i;
                }
            }
            final parentId = resource.id.substring(0, lastIndex);

            var depthMap = parentMap[depth];
            if (depthMap == null) {
                depthMap = {};
                parentMap[depth] = depthMap;
            }

            var siblings = depthMap[parentId];
            if (siblings == null) {
                siblings = [];
                depthMap[parentId] = siblings;
            }

            siblings.add(resource);
        }

        List<ResourceTreeNode> buildTree(int depth, String parentId) {
            final depthMap = parentMap[depth]; 
            if (depthMap == null) return const [];

            final children = depthMap[parentId] ?? [];
            
            return children.map((child) {
                final details = child.installableDetails;
                final isInstalled = details?.installState == InstallState.installed;
                final needsUpdate =
                    isInstalled && details?.localUpdatedAt != details?.serverUpdatedAt;

                final children = buildTree(depth + 1, child.id);
                final descendantStaleCount = children.fold(
                    0,
                    (count, child) => count + child.descendantStaleCount + (child.needsUpdate ? 1 : 0)
                );

                return ResourceTreeNode(
                    id: child.id,
                    resourceName: child.resourceName,
                    isInstalled: isInstalled,
                    needsUpdate: needsUpdate,
                    children: children,
                    descendantStaleCount: descendantStaleCount,
                );
            }).toList();
        }

        return buildTree(0, '');
    }
}
