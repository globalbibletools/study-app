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
        return SimpleDialog(
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const Locale('en')),
              child: const Text('English'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const Locale('es')),
              child: const Text('Español'),
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
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settings)),
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, widget) {
          return ListView(
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: Text(
                  AppLocalizations.of(context)!.currentLanguage,
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
              ListTile(
                title: Text(AppLocalizations.of(context)!.hebrewGreekTextSize),
                trailing: Text(
                  '${manager.textSize}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () {
                  _showFontSizeDialog(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<dynamic> _showFontSizeDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            content: SizedBox(
              height: 150,
              child: StatefulBuilder(
                builder:
                    (context, setState) => Column(
                      children: [
                        const Spacer(),
                        Text(
                          'א α',
                          style: TextStyle(fontSize: manager.textSize),
                        ),
                        const Spacer(),
                        Slider(
                          value: manager.textSize,
                          min: manager.minFontSize,
                          max: manager.maxFontSize,
                          divisions: manager.fontSizeDivisions,
                          label: manager.textSize.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              manager.setTextSize(value);
                            });
                          },
                        ),
                      ],
                    ),
              ),
            ),
          ),
    );
  }
}
