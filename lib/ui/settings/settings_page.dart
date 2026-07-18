import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/service_locator.dart';

import 'settings_manager.dart';
import 'section_font_size.dart';

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

  /// Sentinel representing "no gloss language" in the picker.
  static final _noneGloss = GlossResource(name: '', code: '');

  Future<GlossResource?> _chooseGlossLanguage() async {
    return await showDialog<GlossResource>(
      context: context,
      builder: (BuildContext context) {
        final textStyle = Theme.of(context).textTheme.bodyLarge;
        return SimpleDialog(
          title: Text(AppLocalizations.of(context)!.glossLanguage),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _noneGloss),
              child: Text(AppLocalizations.of(context)!.glossNone, style: textStyle),
            ),
            ...manager.glossResources.map((resource) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, resource),
                child: Text(resource.name, style: textStyle),
              );
            }),
          ],
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

              // Gloss Language
              ListTile(
                title: Text(l10n.glossLanguage),
                trailing: Text(
                  manager.currentGlossLangName ?? l10n.glossNone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () async {
                  final previousCode = manager.currentGlossLangCode;
                  final selected = await _chooseGlossLanguage();
                  // Dismissed without a selection.
                  if (selected == null) return;

                  // User chose "None" — unset the gloss language.
                  if (selected == _noneGloss) {
                    await manager.setGlossLang(null);
                    return;
                  }

                  if (selected.code == previousCode) {
                    return;
                  }

                  // Immediately set so the UI reflects the selection
                  await manager.setGlossLang(selected.code);

                  if (!context.mounted) return;

                  final success = await ResourceUIHelper.ensureGloss(
                    context,
                    selected.code,
                  );

                  if (!success && context.mounted) {
                    // Revert if they cancelled or it failed
                    await manager.setGlossLang(previousCode);
                  }
                },
              ),

              // Theme mode
              ListTile(
                title: Text(l10n.theme),
                subtitle: Text(
                  manager.currentThemeMode == ThemeMode.light
                      ? l10n.lightTheme
                      : manager.currentThemeMode == ThemeMode.dark
                      ? l10n.darkTheme
                      : l10n.systemDefault,
                ),
                trailing: Icon(
                  manager.currentThemeMode == ThemeMode.light
                      ? Icons.light_mode
                      : manager.currentThemeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.smartphone,
                ),
                onTap: () async {
                  final selectedMode = await _chooseThemeMode();
                  if (selectedMode != null) {
                    manager.setThemeMode(selectedMode);
                  }
                },
              ),

              // Verse Layout
              ListTile(
                title: Text(l10n.verseLayout),
                subtitle: Text(
                  manager.verseLayout == VerseLayout.versePerLine
                      ? l10n.versePerLine
                      : l10n.paragraph,
                ),
                onTap: () async {
                  final selectedLayout = await _chooseVerseLayout();
                  if (selectedLayout != null) {
                    manager.setVerseLayout(selectedLayout);
                  }
                },
              ),

              FontSizeSection(),
            ],
          );
        },
      ),
    );
  }

  Future<ThemeMode?> _chooseThemeMode() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.system,
              icon: Icon(Icons.smartphone),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
            ),
          ],
          selected: {manager.currentThemeMode},
          onSelectionChanged: (Set<ThemeMode> selection) {
            manager.setThemeMode(selection.first);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }


  Future<VerseLayout?> _chooseVerseLayout() async {
    final l10n = AppLocalizations.of(context)!;

    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SegmentedButton<VerseLayout>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment<VerseLayout>(
              value: VerseLayout.paragraph,
              label: Text(l10n.paragraph),
            ),
            ButtonSegment<VerseLayout>(
              value: VerseLayout.versePerLine,
              label: Text(l10n.versePerLine),
            ),
          ],
          selected: {manager.verseLayout},
          onSelectionChanged: (Set<VerseLayout> selection) {
            manager.setVerseLayout(selection.first);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

