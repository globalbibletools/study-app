import 'package:flutter/material.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'reference_chooser/reference_chooser.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int displayBookId;
  final int displayChapter;
  final int displayVerse;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;
  final VoidCallback onTogglePanel;
  final VoidCallback onPlayAudio;
  final GlobalKey<ReferenceChooserState> referenceChooserKey;
  final ValueChanged<ReferenceInputMode> onInputModeChanged;
  final ValueChanged<Set<int>>? onAvailableDigitsChanged;

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
    this.onAvailableDigitsChanged,
  });

  @override
  Widget build(BuildContext context) {
    print("DEBUG: HomeAppBar Rebuild");
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
        IconButton(onPressed: onPlayAudio, icon: Icon(Icons.play_arrow)),
        IconButton(onPressed: onTogglePanel, icon: Icon(Icons.splitscreen)),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
