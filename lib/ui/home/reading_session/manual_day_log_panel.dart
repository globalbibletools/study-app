import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';

class ManualDayLogPanel extends StatefulWidget {
  const ManualDayLogPanel({super.key});

  @override
  State<ManualDayLogPanel> createState() => _ManualDayLogPanelState();
}

class _ManualDayLogPanelState extends State<ManualDayLogPanel> {
  int _minutes = 0;
  int _verses = 0;

  bool get _canSave => _minutes > 0 || _verses > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.logReadingTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.logReadingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                _stepperRow(
                  label: l10n.minutes,
                  value: _minutes,
                  onDecrement: _minutes > 0
                      ? () => setState(() => _minutes--)
                      : null,
                  onIncrement: () => setState(() => _minutes++),
                ),
                const SizedBox(height: 16),
                _stepperRow(
                  label: l10n.verses,
                  value: _verses,
                  onDecrement: _verses > 0
                      ? () => setState(() => _verses--)
                      : null,
                  onIncrement: () => setState(() => _verses++),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: colorScheme.primary),
                        ),
                        child: Text(l10n.cancel.toUpperCase()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canSave
                            ? () => Navigator.pop(context, (_minutes, _verses))
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.save.toUpperCase()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepperRow({
    required String label,
    required int value,
    required VoidCallback? onDecrement,
    required VoidCallback onIncrement,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        _circleButton(
          icon: Icons.remove,
          onTap: onDecrement,
          colorScheme: colorScheme,
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
          ),
        ),
        _circleButton(
          icon: Icons.add,
          onTap: onIncrement,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
