import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

Future<void> showParallelTranslationsSheet(
  BuildContext context, {
  VoidCallback? onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return ParallelTranslationsSheet(
            scrollController: scrollController,
            onChanged: onChanged,
          );
        },
      );
    },
  );
}

class ParallelTranslationsSheet extends StatefulWidget {
  const ParallelTranslationsSheet({
    super.key,
    this.scrollController,
    this.onChanged,
  });

  final ScrollController? scrollController;
  final VoidCallback? onChanged;

  @override
  State<ParallelTranslationsSheet> createState() =>
      _ParallelTranslationsSheetState();
}

class _ParallelTranslationsSheetState extends State<ParallelTranslationsSheet> {
  final _resourceService = getIt<ResourceService>();
  final _settings = getIt<UserSettings>();

  List<Resource> _resources = [];
  bool _loading = true;
  late Set<String> _selectedBibles;

  @override
  void initState() {
    super.initState();
    _selectedBibles = _settings.occurrenceParallelBibles.toSet();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final resources = await _resourceService.getResourcesByType(
        ResourceType.bible,
      );
      if (mounted) {
        setState(() {
          _resources = resources;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleBible(Resource resource) async {
    final isInstalled =
        resource.installableDetails?.installState == InstallState.installed ||
        await _resourceService.resourceExists(
          ResourceType.bible,
          resource.id,
        );

    if (!isInstalled) {
      if (!mounted) return;
      final downloaded = await ResourceUIHelper.ensureResource(
        context,
        ResourceType.bible,
        resource.id,
      );
      if (!downloaded || !mounted) return;
    }

    setState(() {
      if (_selectedBibles.contains(resource.id)) {
        _selectedBibles.remove(resource.id);
      } else {
        _selectedBibles.add(resource.id);
      }
    });

    await _settings.setOccurrenceParallelBibles(_selectedBibles.toList());
    widget.onChanged?.call();
    await _loadResources();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                'Parallel Translations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _resources.isEmpty
                  ? Center(child: Text(l10n.bibleTranslation))
                  : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _resources.length,
                    itemBuilder: (context, index) {
                      final resource = _resources[index];
                      final isSelected = _selectedBibles.contains(resource.id);
                      final isInstalled =
                          resource.installableDetails?.installState ==
                          InstallState.installed;

                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleBible(resource),
                        title: Text(
                          resource.resourceName.isNotEmpty
                              ? resource.resourceName
                              : resource.id,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle:
                            resource.creatorName != null &&
                                    resource.creatorName!.isNotEmpty
                                ? Text(resource.creatorName!)
                                : null,
                        secondary:
                            !isInstalled
                                ? IconButton(
                                  icon: const Icon(Icons.download),
                                  tooltip: l10n.download,
                                  onPressed: () => _toggleBible(resource),
                                )
                                : null,
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
