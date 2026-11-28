import 'package:gbt/changelog/changelog_entry.dart';
import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/changelog/changelog_view.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({super.key, required this.entry});

  final ChangelogEntry entry;

  static Future<void> showOnStartup(BuildContext context) async {
    final changelogService = getIt<ChangelogService>();
    final locale = Localizations.localeOf(context);

    ChangelogEntry? entry;
    try {
      entry = await changelogService.latestUnseenMajor(locale);
    } catch (err, stack) {
      error(
        'Failed to load changelog on startup',
        error: err,
        stackTrace: stack,
      );
      return;
    }

    if (entry == null || !context.mounted) return;
    final unseenEntry = entry;

    final readChangelog = await showDialog<bool>(
      context: context,
      builder: (_) => ChangelogDialog(entry: unseenEntry),
    );

    if (readChangelog == true) {
      if (!context.mounted) return;
      await ChangelogView.navigateTo(context);
    } else {
      await changelogService.markLatestSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.whatsNew),
          Text(entry.version, style: textTheme.bodyMedium),
        ],
      ),
      content: Text(entry.summary!),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.dismiss),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.readChangelog),
        ),
      ],
    );
  }
}
