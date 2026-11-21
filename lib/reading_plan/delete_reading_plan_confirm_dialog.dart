import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';

class DeleteReadingPlanConfirmDialog extends StatelessWidget {
  const DeleteReadingPlanConfirmDialog({super.key, required this.planName});

  final String planName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.deleteReadingPlanConfirmTitle),
      content: Text(l10n.deleteReadingPlanConfirmMessage(planName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}
