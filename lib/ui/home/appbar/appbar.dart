import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/ui/home/appbar/reading_session_timer_view.dart';
import 'reference_chooser/reference_chooser.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int displayBookId;
  final int displayChapter;
  final int displayVerse;
  final bool readingSessionStarted;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;
  final VoidCallback onTogglePanel;
  final VoidCallback onPlayAudio;
  final GlobalKey<ReferenceChooserState> referenceChooserKey;
  final ValueChanged<ReferenceInputMode> onInputModeChanged;
  final ValueChanged<Set<int>>? onAvailableDigitsChanged;
  final VoidCallback onToggleReadingSession;

  const HomeAppBar({
    super.key,
    required this.displayBookId,
    required this.displayChapter,
    required this.displayVerse,
    required this.onBookSelected,
    required this.onChapterSelected,
    required this.onVerseSelected,
    required this.onTogglePanel,
    required this.onPlayAudio,
    required this.referenceChooserKey,
    required this.onInputModeChanged,
    required this.onToggleReadingSession,
    required this.readingSessionStarted,
    this.onAvailableDigitsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: ReferenceChooser(
        key: referenceChooserKey,
        currentBookName: bookNameFromId(context, displayBookId),
        currentBookId: displayBookId,
        currentChapter: displayChapter,
        currentVerse: displayVerse,
        onBookSelected: onBookSelected,
        onChapterSelected: onChapterSelected,
        onVerseSelected: onVerseSelected,
        onInputModeChanged: onInputModeChanged,
        onAvailableDigitsChanged: onAvailableDigitsChanged,
      ),
      actions: [
        _readingSessionTimer(readingSessionStarted),
        IconButton(
          onPressed: onToggleReadingSession,
          style: IconButton.styleFrom(
            backgroundColor: readingSessionStarted
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            foregroundColor: readingSessionStarted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).iconTheme.color,
          ),
          icon: Icon(
            readingSessionStarted ? Icons.auto_stories_rounded : Icons.menu_book_outlined,
          ),
        ),
        IconButton(onPressed: onPlayAudio, icon: Icon(Icons.play_arrow)),
        IconButton(onPressed: onTogglePanel, icon: Icon(Icons.splitscreen)),
      ],
    );
  }

  Widget _readingSessionTimer(bool readingSessionStarted) {
    if (readingSessionStarted) {
      return ReadingSessionTimerView();
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
