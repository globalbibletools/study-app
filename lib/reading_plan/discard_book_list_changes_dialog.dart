import 'package:gbt/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class DiscardBookListChangesDialog extends StatelessWidget {
  const DiscardBookListChangesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.discardBookListChangesTitle),
      content: Text(l10n.discardBookListChangesMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.keepEditing),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.discardChanges),
        ),
      ],
    );
  }
}
