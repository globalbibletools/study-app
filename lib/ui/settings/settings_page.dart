import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';

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
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const Locale('en')),
              child: Text('English', style: textStyle),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const Locale('es')),
              child: Text('Español', style: textStyle),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDownloadDialog(
    Locale previousLocale,
    Locale newLocale,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final shouldDownload =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              content: Text(l10n.downloadGlossesMessage),
              actions: <Widget>[
                TextButton(
                  child: Text(l10n.cancel),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                FilledButton(
                  child: Text(l10n.download),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return;

    if (!shouldDownload) {
      await manager.setLocale(previousLocale);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.downloadingGlossesMessage),
          duration: const Duration(seconds: 30),
        ),
      );

      try {
        await manager.downloadGlosses(newLocale);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
      } catch (e) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
      }
    }
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
                  l10n.currentLanguage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () async {
                  final previousLocale = manager.currentLocale;
                  final selectedLocale = await _chooseLocale();
                  if (selectedLocale == null) return;
                  await manager.setLocale(selectedLocale);
                  if (selectedLocale.languageCode == 'en') return;
                  final isDownloaded = await manager.isLocaleDownloaded(
                    selectedLocale,
                  );
                  if (isDownloaded) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await _showDownloadDialog(previousLocale, selectedLocale);
                  });
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

              // EXPANDABLE TEXT SIZE SECTION
              ExpansionTile(
                title: Text(l10n.textSize),
                children: [
                  // 1. Hebrew/Greek
                  ListTile(
                    title: Text(l10n.hebrewGreekTextSize),
                    trailing: Text('${manager.hebrewTextSize.toInt()}'),
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    onTap: () {
                      _showFontSizeDialog(
                        context,
                        previewText: 'א α',
                        currentValue: manager.hebrewTextSize,
                        onChanged: manager.setHebrewTextSize,
                      );
                    },
                  ),
                  // 2. Second Panel
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
                  // 3. Lexicon
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
                  Text(
                    previewText,
                    // Use the value from the manager (via parent rebuild)
                    // or the local currentValue if you want instant preview without parent rebuilds.
                    // Since ListenableBuilder wraps the ListView, manager updates reflect immediately.
                    style: TextStyle(fontSize: currentValue),
                  ),
                  const Spacer(),
                  Slider(
                    value: currentValue,
                    min: manager.minFontSize,
                    max: manager.maxFontSize,
                    divisions: manager.fontSizeDivisions,
                    label: currentValue.toStringAsFixed(1),
                    onChanged: (value) {
                      // Update the manager (which rebuilds the Page)
                      onChanged(value);
                      // Update local dialog state to move the slider
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
}
