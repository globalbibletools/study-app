import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

class BibleSection extends StatefulWidget {
  const BibleSection({super.key});

  @override
  State<BibleSection> createState() => _BibleSectionState();
}

class _BibleSectionState extends State<BibleSection> {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  List<ResourceView> bibleResources = [];

  @override
  void initState() {
    super.initState();
    _initBibleResources();
  }

  Future<void> _initBibleResources() async {
    try {
      bibleResources = await _resourceService.getResourcesByType(ResourceType.bible);
      setState(() {});
    } catch (err, stack) {
      log('Failed to initialize bible resources', error: err, stackTrace: stack);
    }
  }


  /// Sentinel representing "no gloss language" in the picker.
  static final _noneBible = ResourceView(
    id: '',
    resourceName: '',
  );

  String? get currentBibleId => _settings.currentBible;

  String? get currentBibleName {
    final code = currentBibleId;
    if (code == null) return null;

    try {
      return bibleResources.firstWhere((r) => r.id == code).resourceName;
    } catch (err) {
      return null;
    }
  }

  Future<void> setBible(String? id) async {
    await _settings.setCurrentBible(id);
    setState(() {});
  }

  Future<void> _chooseBible() async {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final previousBibleId = currentBibleId;

    final selected = await showDialog<ResourceView>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.bibleTranslation),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _noneBible),
              child: Text(l10n.glossNone, style: textStyle),
            ),
            ...bibleResources.map((resource) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, resource),
                child: Text(resource.resourceName, style: textStyle),
              );
            }),
          ],
        );
      },
    );

    if (selected == null || selected.id == previousBibleId) return;

    if (selected == _noneBible) {
      await setBible(null);
      return;
    }

    await setBible(selected.id);

    if (!context.mounted) return;
    final success = await ResourceUIHelper.ensureResource(
      context,
      ResourceType.bible,
      selected.id,
    );

    // Revert if they cancelled or it failed
    if (!success && context.mounted) {
      await setBible(previousBibleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.bibleTranslation),
      trailing: Text(
        currentBibleName ?? l10n.glossNone,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () {
        _chooseBible();
      },
    );
  }
}

