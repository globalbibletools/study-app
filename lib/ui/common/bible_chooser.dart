import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

class BibleOption {
  const BibleOption(this.id, this.name);

  final String id;
  final String name;
}

Future<bool> chooseBible(BuildContext context) async {
  final settings = getIt<UserSettings>();
  final resourceService = getIt<ResourceService>();
  final l10n = AppLocalizations.of(context)!;
  final textStyle = Theme.of(context).textTheme.bodyLarge;

  final resources = await resourceService.getResourcesByType(
    ResourceType.bible,
  );
  if (!context.mounted) return false;
  final options = [
    for (final r in resources) BibleOption(r.id, r.resourceName),
  ];

  final previousBibleId = settings.currentBible;

  final selected = await showDialog<BibleOption>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.bibleTranslation),
      children: options.map((resource) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, resource),
          child: Text(resource.name, style: textStyle),
        );
      }).toList(),
    ),
  );

  if (selected == null) return false;

  if (selected.id != previousBibleId) {
    await settings.setCurrentBible(selected.id);
  }

  if (!context.mounted) return false;
  final success = await ResourceUIHelper().ensureResource(
    context,
    ResourceType.bible,
    selected.id,
  );

  if (!success) {
    // Revert to whatever was selected before so we don't point at a Bible
    // that isn't usable.
    await settings.setCurrentBible(previousBibleId);
    return false;
  }

  return true;
}
