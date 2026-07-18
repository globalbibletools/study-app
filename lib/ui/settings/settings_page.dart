import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';

import 'section_font_size.dart';
import 'section_gloss_language.dart';
import 'section_language.dart';
import 'section_theme.dart';
import 'section_verse_layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: const [
          LanguageSection(),
          GlossLanguageSection(),
          ThemeSection(),
          VerseLayoutSection(),
          FontSizeSection(),
        ],
      ),
    );
  }
}
