import 'package:material_ui/material_ui.dart';
import 'package:gbt/design/severity_colors.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/ui/messaging/ephemeral_message.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

class MessengerHost extends StatelessWidget {
  const MessengerHost({
    super.key,
    required this.messenger,
    required this.child,
  });

  static const cardKey = Key('ephemeralMessageCard');

  static const dismissButtonKey = Key('ephemeralMessageDismiss');

  final MessengerViewModel messenger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: messenger,
            builder: (context, _) {
              final message = messenger.visibleMessage;
              return IgnorePointer(
                ignoring: message == null,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offset = Tween<Offset>(
                          begin: const Offset(0, -0.35),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offset,
                            child: child,
                          ),
                        );
                      },
                      child: message == null
                          ? const SizedBox.shrink(key: ValueKey('empty'))
                          : _MessageCard(
                              key: ValueKey(message.id),
                              message: message,
                              onDismiss: messenger.dismissVisible,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final EphemeralMessage message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final severity = context.severityColors;
    final (background, icon) = switch (message.severity) {
      MessageSeverity.info ||
      MessageSeverity.success => (severity.infoBackground, severity.infoIcon),
      MessageSeverity.warning => (
        severity.warningBackground,
        severity.warningIcon,
      ),
      MessageSeverity.error => (severity.errorBackground, severity.errorIcon),
    };
    final foreground = theme.colorScheme.onSurface;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          key: MessengerHost.cardKey,
          color: background,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                ExcludeSemantics(
                  child: Icon(_icon(message.severity), color: icon, size: 20),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: MessengerHost.dismissButtonKey,
                  onPressed: onDismiss,
                  color: foreground,
                  iconSize: 20,
                  icon: Icon(Icons.close, semanticLabel: l10n.dismiss),
                  alignment: Alignment.topCenter,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    maximumSize: const Size(28, 28),
                    alignment: Alignment.topCenter,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _icon(MessageSeverity severity) => switch (severity) {
  MessageSeverity.info => Icons.info_outline,
  MessageSeverity.success => Icons.check_circle_outline,
  MessageSeverity.warning => Icons.warning_amber_rounded,
  MessageSeverity.error => Icons.error_outline,
};
