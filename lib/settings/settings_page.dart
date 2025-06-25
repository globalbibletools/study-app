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

  Future<Language?> _chooseLanguage() async {
    return await showDialog<Language>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, Language.english),
              child: const Text('English'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, Language.spanish),
              child: const Text('Español'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDownloadDialog(
    Language previousLanguage,
    Language newLanguage,
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
      await manager.setLanguage(previousLanguage);
    } else {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.downloadingGlossesMessage),
          duration: const Duration(seconds: 30),
        ),
      );

      try {
        await manager.downloadGlosses(newLanguage);
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
                  final previousLanguage = manager.currentLanguage;
                  final selectedLanguage = await _chooseLanguage();
                  if (selectedLanguage == null) return;
                  await manager.setLanguage(selectedLanguage);
                  if (selectedLanguage == Language.english) return;
                  final isDownloaded = await manager.isLanguageDownloaded(
                    selectedLanguage,
                  );
                  if (isDownloaded) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await _showDownloadDialog(
                      previousLanguage,
                      selectedLanguage,
                    );
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
