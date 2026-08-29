import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/ui/common/bible_chooser.dart';

class BibleSection extends StatefulWidget {
  const BibleSection({super.key});

  @override
  State<BibleSection> createState() => _BibleSectionState();
}

class _BibleSectionState extends State<BibleSection> {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  List<BibleOption> bibleResources = [];

  @override
  void initState() {
    super.initState();
    _initBibleResources();
  }

  Future<void> _initBibleResources() async {
    try {
      final resources = await _resourceService.getResourcesByType(ResourceType.bible);
      if (!mounted) return;
      setState(() {
          bibleResources = resources.map((resource) => BibleOption(resource.id, resource.resourceName)).toList();
      });
    } catch (err, stack) {
      log('Failed to initialize bible resources', error: err, stackTrace: stack);
    }
  }

  String? get currentBibleId => _settings.currentBible;

  String? get currentBibleName {
    final code = currentBibleId;
    if (code == null) return null;

    try {
      return bibleResources.firstWhere((r) => r.id == code).name;
    } catch (err) {
      return null;
    }
  }

  Future<void> _chooseBible() async {
    await chooseBible(context, allowNone: true);
    if (mounted) setState(() {});
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
