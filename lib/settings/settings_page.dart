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

  Future<void> _chooseLanguage() async {
    final selectedLanguage = await showDialog<Language>(
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

    if (selectedLanguage != null) {
      manager.setLanguage(selectedLanguage);
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
                onTap: () {
                  _chooseLanguage();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
