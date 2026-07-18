import 'package:flutter/material.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

class LanguageSection extends StatefulWidget {
  const LanguageSection({super.key});

  @override
  State<LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<LanguageSection> {
  final _settings = getIt<UserSettings>();
  final _appState = getIt<AppState>();

  Locale get currentLocale => _settings.locale;

  String get currentLanguageName {
    final config = AppLanguages.getConfig(currentLocale.languageCode);
    return config.nativeName;
  }

  Future<void> setLocale(Locale locale) async {
    await _settings.setLocale(locale.languageCode);
    _appState.init();
    setState(() {});
  }

  Future<void> _chooseLocale() async {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final previousLocale = currentLocale;

    final selectedLocale = await showDialog<Locale>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.language),
          children: AppLanguages.supported.map((config) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, Locale(config.code)),
              child: Text(config.nativeName, style: textStyle),
            );
          }).toList(),
        );
      },
    );

    if (selectedLocale == null || selectedLocale == previousLocale) return;

    // Immediately set locale so UI language changes
    await setLocale(selectedLocale);

    // English needs no downloaded resources
    if (selectedLocale.languageCode == 'en') return;

    if (!context.mounted) return;
    final success = await ResourceUIHelper.ensureResources(
      context,
      selectedLocale,
    );

    // Revert if they cancelled or it failed
    if (!success && context.mounted) {
      await setLocale(previousLocale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.language),
      trailing: Text(
        currentLanguageName,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () {
        _chooseLocale();
      },
    );
  }
}
