import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/ui/home/panel_area/common/confetti_view.dart';

class GoalReachedOverlay extends StatefulWidget {
  const GoalReachedOverlay({super.key, required this.manager});

  final ReadingSessionManager manager;

  @override
  State<GoalReachedOverlay> createState() => _GoalReachedOverlayState();
}

class _GoalReachedOverlayState extends State<GoalReachedOverlay> {
  static const _celebrationDuration = Duration(seconds: 2);

  Timer? _transitionTimer;
  bool _showContinuePrompt = false;

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _handleGoalReachedChanged(bool goalReached) {
    if (!goalReached) {
      _transitionTimer?.cancel();
      if (_showContinuePrompt) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _showContinuePrompt = false;
            });
          }
        });
      }
      return;
    }

    if (_transitionTimer != null || _showContinuePrompt) {
      return;
    }

    _transitionTimer = Timer(_celebrationDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showContinuePrompt = true;
      });
      _transitionTimer = null;
    });
  }

  void _dismissOverlay() {
    widget.manager.goalReachedNotifier.value = false;
  }

  Future<void> _endSession() async {
    _dismissOverlay();
    await widget.manager.endReadingSession();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.manager.goalReachedNotifier,
      builder: (context, goalReached, _) {
        _handleGoalReachedChanged(goalReached);

        if (!goalReached) {
          return const SizedBox.shrink();
        }

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
                        onYes: _dismissOverlay,
                        onNo: _endSession,
                      )
                    : const _GoalReachedMessage(
                        key: ValueKey('goal-reached-message'),
                      ),
              ),
            ],
          ),
        );
      },
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
