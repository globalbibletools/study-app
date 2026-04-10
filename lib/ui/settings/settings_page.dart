import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_languages.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/ui/common/resource_ui_helper.dart';
import 'package:studyapp/services/settings/user_settings.dart';

import 'settings_manager.dart';

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

              // EXPANDABLE TEXT SIZE SECTION
              ExpansionTile(
                title: Text(l10n.textSize),
                children: [
                  // 1. Hebrew
                  ListTile(
                    title: Text(l10n.hebrewTextSize),
                    trailing: Text('${manager.hebrewTextSize.toInt()}'),
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    onTap: () {
                      _showFontSizeDialog(
                        context,
                        previewText: 'א',
                        currentValue: manager.hebrewTextSize,
                        onChanged: manager.setHebrewTextSize,
                      );
                    },
                  ),
                  // 2. Greek
                  ListTile(
                    title: Text(l10n.greekTextSize),
                    trailing: Text('${manager.greekTextSize.toInt()}'),
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    onTap: () {
                      _showFontSizeDialog(
                        context,
                        previewText: 'α',
                        currentValue: manager.greekTextSize,
                        onChanged: manager.setGreekTextSize,
                      );
                    },
                  ),
                  // 3. Second Panel
                  ListTile(
                    title: Text(l10n.secondPanelTextSize),
                    trailing: Text('${manager.bibleTextSize.toInt()}'),
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    onTap: () {
                      _showFontSizeDialog(
                        context,
                        previewText: 'A a',
                        currentValue: manager.bibleTextSize,
                        onChanged: manager.setBibleTextSize,
                      );
                    },
                  ),
                  // 4. Lexicon
                  ListTile(
                    title: Text(l10n.lexiconTextSize),
                    trailing: Text('${manager.lexiconTextSize.toInt()}'),
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    onTap: () {
                      _showFontSizeDialog(
                        context,
                        previewText: 'A a',
                        currentValue: manager.lexiconTextSize,
                        onChanged: manager.setLexiconTextSize,
                      );
                    },
                  ),
                ],
              ),
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

  Future<dynamic> _showFontSizeDialog(
    BuildContext context, {
    required double currentValue,
    required Function(double) onChanged,
    required String previewText,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          height: 150,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  const Spacer(),
                  Text(previewText, style: TextStyle(fontSize: currentValue)),
                  const Spacer(),
                  Slider(
                    value: currentValue,
                    min: manager.minFontSize,
                    max: manager.maxFontSize,
                    divisions: manager.fontSizeDivisions,
                    label: currentValue.toStringAsFixed(1),
                    onChanged: (value) {
                      onChanged(value);
                      setState(() {
                        currentValue = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
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
