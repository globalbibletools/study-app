import 'package:gbt/changelog/changelog_service.dart';
import 'package:gbt/changelog/changelog_view.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:material_ui/material_ui.dart';

class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({super.key});

  static Future<void> showOnStartup(BuildContext context) async {
    final changelogService = getIt<ChangelogService>();
    final locale = Localizations.localeOf(context);

    bool shouldShow;
    try {
      shouldShow = await changelogService.shouldShowUpdateDialog(locale);
    } catch (err, stack) {
      error(
        'Failed to load changelog on startup',
        error: err,
        stackTrace: stack,
      );
      return;
    }

    if (!shouldShow || !context.mounted) return;

    final readChangelog = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangelogDialog(),
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

    return AlertDialog(
      title: Text(l10n.whatsNew),
      content: Text(l10n.whatsNewMessage),
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
