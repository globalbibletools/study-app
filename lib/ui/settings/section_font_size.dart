import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/service_locator.dart';

class FontSizeSection extends StatefulWidget {
  const FontSizeSection({super.key});

  @override
  State<FontSizeSection> createState() => _FontSizeSectionState();
}

class _FontSizeSectionState extends State<FontSizeSection> {
  final _settings = getIt<UserSettings>();

  double get minFontSize => 10;
  double get maxFontSize => 60;

  double get hebrewTextSize =>
      (_settings.baseFontSize * _settings.hebrewFontScale).roundToDouble();

  Future<void> setHebrewTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setHebrewFontScale(scale);
    setState(() {});
  }

  double get greekTextSize =>
      (_settings.baseFontSize * _settings.greekFontScale).roundToDouble();

  Future<void> setGreekTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setGreekFontScale(scale);
    setState(() {});
  }

  double get bibleTextSize =>
      (_settings.baseFontSize * _settings.bibleFontScale).roundToDouble();

  Future<void> setBibleTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setBibleFontScale(scale);
    setState(() {});
  }

  double get lexiconTextSize =>
      (_settings.baseFontSize * _settings.wordDetailsFontScale).roundToDouble();

  Future<void> setLexiconTextSize(double fontSize) async {
    final scale = fontSize / _settings.baseFontSize;
    await _settings.setWordDetailsFontScale(scale);
    setState(() {});
  }

  Future<void> _showFontSizeDialog(
    BuildContext context, {
    required double currentValue,
    required String previewText,
    required Function(double) onChanged,
  }) async {
    await showDialog(
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
                    min: minFontSize,
                    max: maxFontSize,
                    divisions: (maxFontSize - minFontSize).toInt(),
                    label: currentValue.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        onChanged(value);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ExpansionTile(
      title: Text(l10n.textSize),
      children: [
        ListTile(
          title: Text(l10n.hebrewTextSize),
          trailing: Text('${hebrewTextSize.toInt()}'),
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () {
            _showFontSizeDialog(
              context,
              previewText: 'א',
              currentValue: hebrewTextSize,
              onChanged: setHebrewTextSize,
            );
          },
        ),
        ListTile(
          title: Text(l10n.greekTextSize),
          trailing: Text('${greekTextSize.toInt()}'),
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () {
            _showFontSizeDialog(
              context,
              previewText: 'α',
              currentValue: greekTextSize,
              onChanged: setGreekTextSize,
            );
          },
        ),
        ListTile(
          title: Text(l10n.secondPanelTextSize),
          trailing: Text('${bibleTextSize.toInt()}'),
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () {
            _showFontSizeDialog(
              context,
              previewText: 'A a',
              currentValue: bibleTextSize,
              onChanged: setBibleTextSize,
            );
          },
        ),
        ListTile(
          title: Text(l10n.lexiconTextSize),
          trailing: Text('${lexiconTextSize.toInt()}'),
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () {
            _showFontSizeDialog(
              context,
              previewText: 'A a',
              currentValue: lexiconTextSize,
              onChanged: setLexiconTextSize,
            );
          },
        ),
      ],
    );
  }
}

