import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/service_locator.dart';

import 'settings_manager.dart';
import 'section_font_size.dart';
import 'section_gloss_language.dart';
import 'section_theme.dart';
import 'section_verse_layout.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final manager = SettingsManager();

  Future<Locale?> _chooseLocale() async {
    return await showDialog<Locale>(
      context: context,
      builder: (BuildContext context) {
        final textStyle = Theme.of(context).textTheme.bodyLarge;
        return SimpleDialog(
          title: Text(AppLocalizations.of(context)!.language),
          children: AppLanguages.supported.map((config) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, Locale(config.code)),
              child: Text(config.nativeName, style: textStyle),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, widget) {
          return ListView(
            children: [
              ListTile(
                title: Text(l10n.language),
                trailing: Text(
                  manager.currentLanguageName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () async {
                  final previousLocale = manager.currentLocale;
                  final selectedLocale = await _chooseLocale();
                  if (selectedLocale == null ||
                      selectedLocale == previousLocale) {
                    return;
                  }

                  // Immediately set locale so UI language changes
                  await manager.setLocale(selectedLocale);

                  if (selectedLocale.languageCode == 'en') return;
                  if (!context.mounted) return;
                  final success = await ResourceUIHelper.ensureResources(
                    context,
                    selectedLocale,
                  );

                  if (!success && context.mounted) {
                    // Revert if they cancelled or it failed
                    await manager.setLocale(previousLocale);
                  }
                },
              ),

              GlossLanguageSection(),

              ThemeSection(),

              VerseLayoutSection(),
              FontSizeSection(),
            ],
          );
        },
      ),
    );
  }

}

