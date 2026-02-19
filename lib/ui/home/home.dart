import 'package:flutter/material.dart';
import 'package:studyapp/common/reference.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/l10n/book_names.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/ui/common/download_progress_dialog.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/reference_chooser.dart';
import 'package:studyapp/ui/home/appbar/reference_chooser/numeric_keypad.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';
import 'package:studyapp/ui/home/audio/audio_player.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/bible_panel_area.dart';

import 'appbar/appbar.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();

  // UI-Specific State (Overlays)
  final GlobalKey<ReferenceChooserState> _chooserKey = GlobalKey();
  ReferenceInputMode _inputMode = ReferenceInputMode.none;
  Set<int> _enabledKeypadDigits = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init();
  }

  @override
  void dispose() {
    manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder<Reference>(
          valueListenable: manager.currentReference,
          builder: (context, ref, child) {
            return HomeAppBar(
              referenceChooserKey: _chooserKey,
              displayBookId: ref.bookId,
              displayChapter: ref.chapter,
              displayVerse: ref.verse,
              // Direct calls to Manager
              onBookSelected: (bookId) =>
                  manager.onBookSelected(context, bookId),
              onChapterSelected: (newChapter) =>
                  manager.onChapterSelected(newChapter),
              onVerseSelected: (verse) {
                manager.syncController.jumpToVerse(
                  manager.currentBookId,
                  manager.currentChapter,
                  verse,
                );
              },
              onInputModeChanged: (mode) {
                setState(() {
                  _inputMode = mode;
                });
              },
              onTogglePanel: () {
                manager.togglePanelState();
                // No need to request text manually; panels react to the state change
              },
              onPlayAudio: () {
                _onPlayAudio(context);
              },
              onAvailableDigitsChanged: (digits) {
                if (mounted) {
                  setState(() {
                    _enabledKeypadDigits = digits;
                  });
                }
              },
            );
          },
        ),
      ),
      drawer: AppDrawer(
        onSettingsClosed: () {
          // TODO: Implement settings refresh in Step 3
          // _hebrewGreekPanelKey.currentState?.refreshFromSettings();
          // _biblePanelKey.currentState?.refreshFromSettings();
        },
      ),
      body: Stack(
        children: [
          // 1. The main content (Bible Panels)
          // We wrap this in a Listener only to handle closing the Keypad
          Listener(
            onPointerDown: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (_inputMode != ReferenceInputMode.none) {
                _chooserKey.currentState?.resetAll();
              }
            },
            behavior: HitTestBehavior.translucent,
            // The BiblePanelArea is now isolated
            child: BiblePanelArea(manager: manager),
          ),

          // 2. The Audio Player sliding up from the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<bool>(
              valueListenable: manager.audioManager.isVisibleNotifier,
              builder: (context, isVisible, _) {
                return AnimatedSlide(
                  offset: isVisible ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: BottomAudioPlayer(
                    audioManager: manager.audioManager,
                    currentBookId: manager.currentBookId,
                    currentChapter: manager.currentChapter,
                    currentVerse: manager.currentVerse,
                    currentBookName: bookNameFromId(
                      context,
                      manager.currentBookId,
                    ),
                    onAudioMissing: () => _showDownloadAudioDialog(context),
                  ),
                );
              },
            ),
          ),

          // 3. The Numeric Keypad
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset:
                  (_inputMode == ReferenceInputMode.chapter ||
                      _inputMode == ReferenceInputMode.verse)
                  ? Offset.zero
                  : const Offset(0, 1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Material(
                elevation: 16,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: NumericKeypad(
                  isLastInput: _inputMode == ReferenceInputMode.verse,
                  enabledDigits: _enabledKeypadDigits,
                  onDigit: (d) => _chooserKey.currentState?.handleDigit(d),
                  onBackspace: () =>
                      _chooserKey.currentState?.handleBackspace(),
                  onSubmit: () => _chooserKey.currentState?.handleSubmit(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onPlayAudio(BuildContext context) async {
    // Toggle behavior
    if (manager.audioManager.isVisibleNotifier.value) {
      manager.audioManager.stopAndClose();
      return;
    }

    final bookId = manager.currentBookId;
    final chapter = manager.currentChapter;
    final verse = manager.currentVerse;

    if (!AudioLogic.isAudioAvailable(bookId, chapter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.audioNotAvailable),
        ),
      );
      return;
    }

    try {
      await manager.playAudioForCurrentChapter(
        bookNameFromId(context, bookId),
        chapter,
        startVerse: verse,
      );
    } on AudioMissingException catch (_) {
      if (context.mounted) {
        _showDownloadAudioDialog(context);
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showDownloadAudioDialog(BuildContext context) async {
    final bookName = bookNameFromId(context, manager.currentBookId);
    final l10n = AppLocalizations.of(context)!;

    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.downloadAudio),
          content: Text(
            l10n.audioNotDownloaded(bookName, manager.currentChapter),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.download),
            ),
          ],
        );
      },
    );

    if (shouldDownload != true) return;
    if (!mounted) return;

    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) {
          return manager.downloadAudioForChapter(
            manager.currentBookId,
            manager.currentChapter,
            progress,
            cancelToken,
          );
        },
      );

      if (!mounted) return;
      _onPlayAudio(context);
    } catch (e) {
      if (!mounted) return;
      if (e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download error: $e")));
      }
    }
  }
}
