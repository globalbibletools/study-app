import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/home/home_manager.dart';

class FloatingReturnPill extends StatelessWidget {
  const FloatingReturnPill({super.key, required this.contextData});

  final OccurrenceSearchContext contextData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final homeManager = getIt<HomeManager>();

    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              onTap: () {
                homeManager.setWordStudyOverlayVisible(true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Directionality(
                      textDirection: contextData.word.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        contextData.word.word,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: l10n?.close ?? 'Close',
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: const BoxConstraints(),
              splashRadius: 18,
              onPressed: () {
                homeManager.dismissWordStudySession(keepCurrentLocation: true);
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
