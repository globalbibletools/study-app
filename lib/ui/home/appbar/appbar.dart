import 'package:flutter/material.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'reference_chooser.dart';

enum _HomeMenuAction { splitScreen, playAudio }

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int displayBookId;
  final int displayChapter;
  final int displayVerse;
  final Function(int bookId) onBookSelected;
  final Function(int chapter) onChapterSelected;
  final Function(int verse) onVerseSelected;
  final VoidCallback onTogglePanel;
  final VoidCallback onPlayAudio;

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
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      titleSpacing: 0,
      title: ReferenceChooser(
        currentBookName: bookNameFromId(context, displayBookId),
        currentBookId: displayBookId,
        currentChapter: displayChapter,
        currentVerse: displayVerse,
        onBookSelected: onBookSelected,
        onChapterSelected: onChapterSelected,
        onVerseSelected: onVerseSelected,
      ),
      actions: [
        IconButton(
          onPressed: onPlayAudio,
          icon: Icon(Icons.play_arrow),
          tooltip: AppLocalizations.of(context)!.actionPlayAudio,
        ),
        IconButton(
          onPressed: onTogglePanel,
          icon: Icon(Icons.splitscreen),
          tooltip: AppLocalizations.of(context)!.actionSplitScreen,
        ),
        // PopupMenuButton<_HomeMenuAction>(
        //   icon: const Icon(Icons.more_vert),
        //   onSelected: (action) {
        //     switch (action) {
        //       case _HomeMenuAction.splitScreen:
        //         onTogglePanel();
        //         break;
        //       case _HomeMenuAction.playAudio:
        //         onPlayAudio();
        //         break;
        //     }
        //   },
        //   itemBuilder: (BuildContext context) => [
        //     PopupMenuItem(
        //       value: _HomeMenuAction.splitScreen,
        //       child: Row(
        //         children: [
        //           Icon(Icons.splitscreen),
        //           SizedBox(width: 12),
        //           Text(AppLocalizations.of(context)!.actionSplitScreen),
        //         ],
        //       ),
        //     ),
        //     PopupMenuItem(
        //       value: _HomeMenuAction.playAudio,
        //       child: Row(
        //         children: [
        //           Icon(Icons.play_arrow),
        //           SizedBox(width: 12),
        //           Text(AppLocalizations.of(context)!.actionPlayAudio),
        //         ],
        //       ),
        //     ),
        //   ],
        // ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
