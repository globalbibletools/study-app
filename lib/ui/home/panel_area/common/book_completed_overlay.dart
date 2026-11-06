import 'package:flutter/material.dart';
import 'package:gbt/common/book_name.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/reading_session/rs_manager.dart';

class BookCompletedOverlay extends StatefulWidget {
  const BookCompletedOverlay({
    super.key,
    required this.manager,
    this.onNextBook,
  });

  final ReadingSessionManager manager;

  /// Called when "Next Book in Plan" is pressed.
  final Function(int)? onNextBook;

  @override
  State<BookCompletedOverlay> createState() => _BookCompletedOverlayState();
}

class _BookCompletedOverlayState extends State<BookCompletedOverlay> {
  void _dismissOverlay() {
    widget.manager.bookCompletedNotifier.value = (0, 0);
  }

  void _nextBook(int bookId) {
    _dismissOverlay();
    widget.onNextBook?.call(bookId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<(int, int)>(
      valueListenable: widget.manager.bookCompletedNotifier,
      builder: (context, books, _) {
        final oldBookId = books.$1;
        final newBookId = books.$2;

        if (oldBookId == 0) {
          return const SizedBox.shrink();
        }

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
                    onTap: _dismissOverlay,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
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

                          if (newBookId != 0)
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
                                    Text(
                                      l10n.nextBookInPlan,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    const Icon(Icons.chevron_right, size: 34),
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
                                onPressed: _dismissOverlay,
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
                                child: Text(
                                  l10n.done,
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w400,
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
      },
    );
  }
}
