import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/ui/confetti_view.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/ui/common/stream_dialog_host.dart';

class GoalReachedOverlay extends StatelessWidget {
  const GoalReachedOverlay({super.key, required this.viewModel});

  final ReadingSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return StreamDialogHost<void>(
      stream: viewModel.goalReached,
      builder: (context, _, dismiss) {
        return _GoalReachedDialog(
          onDismiss: dismiss,
          onEndSession: viewModel.endSession,
        );
      },
    );
  }
}

class _GoalReachedDialog extends StatefulWidget {
  const _GoalReachedDialog({
    required this.onDismiss,
    required this.onEndSession,
  });

  final VoidCallback onDismiss;
  final Future<void> Function() onEndSession;

  @override
  State<_GoalReachedDialog> createState() => _GoalReachedDialogState();
}

class _GoalReachedDialogState extends State<_GoalReachedDialog> {
  static const _celebrationDuration = Duration(seconds: 2);

  Timer? _transitionTimer;
  bool _showContinuePrompt = false;

  @override
  void initState() {
    super.initState();
    _transitionTimer = Timer(_celebrationDuration, () {
      if (!mounted) return;

      setState(() => _showContinuePrompt = true);
      _transitionTimer = null;
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  Future<void> _endSession() async {
    widget.onDismiss();
    await widget.onEndSession();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!_showContinuePrompt) IgnorePointer(child: ConfettiOverlay()),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showContinuePrompt
                ? _ContinueReadingPrompt(
                    key: const ValueKey('continue-reading-prompt'),
                    onYes: widget.onDismiss,
                    onNo: _endSession,
                  )
                : const _GoalReachedMessage(
                    key: ValueKey('goal-reached-message'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GoalReachedMessage extends StatelessWidget {
  const _GoalReachedMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.goalReachedMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ContinueReadingPrompt extends StatelessWidget {
  const _ContinueReadingPrompt({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final Future<void> Function() onNo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.continueReadingPrompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: onNo, child: Text(l10n.no)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onYes,
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    child: Text(l10n.yes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
