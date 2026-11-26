import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/ui/common/bible_chooser.dart';
import 'package:gbt/ui/home/settings/reader_settings_view_model.dart';
import 'package:gbt/ui/home/settings/section_bible.dart';
import 'package:gbt/ui/home/settings/section_font_size.dart';
import 'package:gbt/ui/home/settings/section_gloss_language.dart';
import 'package:gbt/ui/home/settings/section_verse_layout.dart';

/// The reader settings sheet body. Receives the view model constructed by
/// [ReaderSettingsSheet.navigateTo] and disposes it when the sheet closes.
class ReaderSettingsPanel extends StatefulWidget {
  const ReaderSettingsPanel({super.key, required this.viewModel});

  final ReaderSettingsViewModel viewModel;

  @override
  State<ReaderSettingsPanel> createState() => ReaderSettingsPanelState();
}

class ReaderSettingsPanelState extends State<ReaderSettingsPanel> {
  late final ReaderSettingsViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = widget.viewModel;
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.readerSettings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _parallelBibleRow(),
                  const GlossLanguageSection(),
                  const BibleSection(),
                  const VerseLayoutSection(),
                  const FontSizeSection(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _parallelBibleRow() {
    final l10n = AppLocalizations.of(context)!;

    return SwitchListTile(
      title: Text(l10n.parallelBible),
      value: viewModel.parallelBibleEnabled,
      onChanged: (value) => viewModel.setParallelBibleEnabled(
        value,
        pickBible: () => chooseBible(context),
      ),
    );
  }
}
