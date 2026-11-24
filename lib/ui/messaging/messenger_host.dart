import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/ui/messaging/ephemeral_message.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

/// The single place ephemeral messages are rendered.
///
/// Mount it through [MaterialApp.builder] so it sits above the app's
/// Navigator. That placement is what keeps a message visible across
/// navigation and above dialogs and modal bottom sheets.
class MessengerHost extends StatelessWidget {
  const MessengerHost({
    super.key,
    required this.messenger,
    required this.child,
  });

  /// Key for the rendered message card, useful for placement assertions.
  static const cardKey = Key('ephemeralMessageCard');

  /// Key for the card's dismiss control.
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
    final palette = _palette(theme, message.severity);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          key: MessengerHost.cardKey,
          color: palette.background,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    _icon(message.severity),
                    color: palette.foreground,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.foreground,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  label: l10n.dismiss,
                  button: true,
                  child: IconButton(
                    key: MessengerHost.dismissButtonKey,
                    onPressed: onDismiss,
                    icon: Icon(Icons.close, color: palette.foreground),
                    iconSize: 20,
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

({Color background, Color foreground}) _palette(
  ThemeData theme,
  MessageSeverity severity,
) {
  final isDark = theme.brightness == Brightness.dark;
  final colors = theme.colorScheme;

  return switch (severity) {
    MessageSeverity.info => (
      background: colors.secondaryContainer,
      foreground: colors.onSecondaryContainer,
    ),
    MessageSeverity.success =>
      isDark
          ? (
              background: const Color(0xFF123B22),
              foreground: const Color(0xFFB7F0C6),
            )
          : (
              background: const Color(0xFFDDF6E3),
              foreground: const Color(0xFF0F4D27),
            ),
    MessageSeverity.warning =>
      isDark
          ? (
              background: const Color(0xFF4A3800),
              foreground: const Color(0xFFFFE0A3),
            )
          : (
              background: const Color(0xFFFFF1CC),
              foreground: const Color(0xFF6B4E00),
            ),
    MessageSeverity.error => (
      background: colors.errorContainer,
      foreground: colors.onErrorContainer,
    ),
  };
}
