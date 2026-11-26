import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';

import 'section_language.dart';
import 'section_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(children: const [LanguageSection(), ThemeSection()]),
    );
  }
}
