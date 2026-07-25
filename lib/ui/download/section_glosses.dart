import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';

/// Collapsing Glosses section shown on the download manager page.
///
/// Currently a placeholder; download content will be added later.
class GlossesSection extends StatelessWidget {
  const GlossesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ExpansionTile(
      leading: const Icon(Icons.translate),
      title: Text(l10n.glosses),
      initiallyExpanded: false,
      children: const [],
    );
  }
}
