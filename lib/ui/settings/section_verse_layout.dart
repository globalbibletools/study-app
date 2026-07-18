import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_languages.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/service_locator.dart';

class VerseLayoutSection extends StatefulWidget {
  const VerseLayoutSection({super.key});

  @override
  State<VerseLayoutSection> createState() => _VerseLayoutSectionState();
}

class _VerseLayoutSectionState extends State<VerseLayoutSection> {
  final _settings = getIt<UserSettings>();

  VerseLayout get verseLayout => _settings.verseLayout;

  Future<void> setVerseLayout(VerseLayout value) async {
    await _settings.setVerseLayout(value);
    setState(() {});
  }

  Future<void> _chooseVerseLayout() async {
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
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
          selected: {verseLayout},
          onSelectionChanged: (Set<VerseLayout> selection) {
            setVerseLayout(selection.first);
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
      title: Text(l10n.verseLayout),
      subtitle: Text(
        verseLayout == VerseLayout.versePerLine
            ? l10n.versePerLine
            : l10n.paragraph,
      ),
      onTap: () {
        _chooseVerseLayout();
      },
    );
  }
}
