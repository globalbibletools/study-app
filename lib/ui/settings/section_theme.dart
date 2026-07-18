import 'package:flutter/material.dart';
import 'package:gbt/app_state.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';

class ThemeSection extends StatefulWidget {
  const ThemeSection({super.key});

  @override
  State<ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<ThemeSection> {
  final _appState = getIt<AppState>();

  ThemeMode get themeMode => _appState.themeMode;

  void setThemeMode(ThemeMode mode) {
    _appState.updateThemeMode(mode);
    setState(() {});
  }

  Future<void> _chooseThemeMode() async {
    await showDialog(
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
          selected: {themeMode},
          onSelectionChanged: (Set<ThemeMode> selection) {
            setThemeMode(selection.first);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.theme),
      subtitle: Text(
        themeMode == ThemeMode.light
            ? l10n.lightTheme
            : themeMode == ThemeMode.dark
            ? l10n.darkTheme
            : l10n.systemDefault,
      ),
      trailing: Icon(
        themeMode == ThemeMode.light
            ? Icons.light_mode
            : themeMode == ThemeMode.dark
            ? Icons.dark_mode
            : Icons.smartphone,
      ),
      onTap: () {
        _chooseThemeMode();
      },
    );
  }
}
