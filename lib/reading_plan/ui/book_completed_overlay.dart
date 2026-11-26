import 'package:material_ui/material_ui.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/reading_plan/reading_session_service.dart';
import 'package:gbt/reading_plan/ui/reading_session_view_model.dart';
import 'package:gbt/ui/common/stream_dialog_host.dart';

class BookCompletedOverlay extends StatelessWidget {
  const BookCompletedOverlay({
    super.key,
    required this.viewModel,
    this.onNextBook,
  });

  final ReadingSessionViewModel viewModel;

  /// Called when "Next Book" is pressed.
  final Function(int)? onNextBook;

  @override
  Widget build(BuildContext context) {
    return StreamDialogHost<BookCompletedEvent>(
      stream: viewModel.bookCompleted,
      builder: (context, event, dismiss) {
        return _BookCompletedDialog(
          event: event,
          onDismiss: dismiss,
          onNextBook: onNextBook,
        );
      },
    );
  }
}

class _BookCompletedDialog extends StatelessWidget {
  const _BookCompletedDialog({
    required this.event,
    required this.onDismiss,
    required this.onNextBook,
  });

  final BookCompletedEvent event;
  final VoidCallback onDismiss;
  final Function(int)? onNextBook;

  void _nextBook(int bookId) {
    onDismiss();
    onNextBook?.call(bookId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oldBookId = event.completedBookId;
    final newBookId = event.nextBookId;

    final cyan = Theme.of(context).primaryColor;

    final oldBookName = bookNameForId(context, oldBookId);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Background overlay
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),

            // Completion card
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.fromLTRB(48, 34, 48, 54),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Check icon
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cyan, width: 2),
                        ),
                        child: Icon(
                          Icons.check,
                          color: cyan,
                          size: 39,
                          weight: 2,
                        ),
                      ),

                      const SizedBox(height: 27),

                      // Completed title
                      Text(
                        l10n.bookCompletedTitle(oldBookName),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.15,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Container(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),

                      const SizedBox(height: 35),

                      if (newBookId != null)
                        // Next book button
                        SizedBox(
                          width: double.infinity,
                          height: 82,
                          child: OutlinedButton(
                            onPressed: () => _nextBook(newBookId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cyan,
                              side: BorderSide(color: cyan, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              disabledForegroundColor: cyan.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      l10n.nextBookInPlan,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                // Nudge the icon up slightly so its center aligns
                                // optically with the text's cap height.
                                Transform.translate(
                                  offset: const Offset(0, -1),
                                  child: const Icon(
                                    Icons.chevron_right,
                                    size: 34,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        // Done button for final book completion
                        SizedBox(
                          width: double.infinity,
                          height: 82,
                          child: OutlinedButton(
                            onPressed: onDismiss,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cyan,
                              side: BorderSide(color: cyan, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                              disabledForegroundColor: cyan.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.done,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
