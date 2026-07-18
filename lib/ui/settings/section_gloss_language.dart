import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/gloss/gloss_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

class GlossLanguageSection extends StatefulWidget {
  const GlossLanguageSection({super.key});

  @override
  State<GlossLanguageSection> createState() => _GlossLanguageSectionState();
}

class _GlossLanguageSectionState extends State<GlossLanguageSection> {
  final _settings = getIt<UserSettings>();
  final _glossDb = getIt<GlossService>();

  /// Sentinel representing "no gloss language" in the picker.
  static final _noneGloss = GlossResource(name: '', code: '');

  List<GlossResource> get glossResources => _glossDb.glossResources;

  String? get currentGlossLangCode => _settings.glossLang;

  String? get currentGlossLangName {
    final code = currentGlossLangCode;
    if (code == null) return null;
    return glossResources
        .firstWhere(
          (r) => r.code == code,
          orElse: () => glossResources.first,
        )
        .name;
  }

  Future<void> setGlossLang(String? code) async {
    await _settings.setGlossLang(code);
    setState(() {});
  }

  Future<void> _chooseGlossLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final previousCode = currentGlossLangCode;

    final selected = await showDialog<GlossResource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.glossLanguage),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _noneGloss),
              child: Text(l10n.glossNone, style: textStyle),
            ),
            ...glossResources.map((resource) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, resource),
                child: Text(resource.name, style: textStyle),
              );
            }),
          ],
        );
      },
    );

    if (selected == null || selected.code == previousCode) return;

    if (selected == _noneGloss) {
      await setGlossLang(null);
      return;
    }

    await setGlossLang(selected.code);

    if (!context.mounted) return;
    final success = await ResourceUIHelper.ensureGloss(
      context,
      selected.code,
    );

    // Revert if they cancelled or it failed
    if (!success && context.mounted) {
      await setGlossLang(previousCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.glossLanguage),
      trailing: Text(
        currentGlossLangName ?? l10n.glossNone,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () {
        _chooseGlossLanguage();
      },
    );
  }
}
