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
import 'package:studyapp/ui/home/bible_panel/bible_panel.dart';
import 'package:studyapp/ui/home/appbar/drawer.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/chapter.dart';
import 'package:studyapp/ui/home/hebrew_greek_panel/panel.dart';

import 'appbar/appbar.dart';
import 'common/scroll_sync_controller.dart';
import 'home_manager.dart';

enum DownloadDialogChoice { useEnglish, download }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final manager = HomeManager();
  final syncController = ScrollSyncController();
  final _hebrewGreekPanelKey = GlobalKey<HebrewGreekPanelState>();
  final _biblePanelKey = GlobalKey<BiblePanelState>();
  final GlobalKey<ReferenceChooserState> _chooserKey = GlobalKey();
  ReferenceInputMode _inputMode = ReferenceInputMode.none;
  Set<int> _enabledKeypadDigits = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

  late int _jumpBookId;
  late int _jumpChapter;

  @override
  void initState() {
    super.initState();
    manager.init();

    _jumpBookId = manager.currentBookId;
    _jumpChapter = manager.currentChapter;

    syncController.addListener(_onScrollUpdate);
    manager.setSyncController(syncController);
  }

  void _onScrollUpdate() {
    final newBook = syncController.bookId;
    final newChapter = syncController.chapter;
    if (newBook == null || newChapter == null) return;
    final newVerse = syncController.verse ?? 1;
    manager.updateReference(newBook, newChapter, newVerse);
    manager.saveBookAndChapter(newBook, newChapter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    manager.init();
  }

  @override
  void dispose() {
    syncController.dispose();
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
              onBookSelected: (bookId) => _onUserNavigation(bookId, 1, 1),
              onChapterSelected: (newChapter) =>
                  _onUserNavigation(ref.bookId, newChapter, 1),
              onVerseSelected: (verse) => _scrollToVerse(verse),
              onInputModeChanged: (mode) {
                setState(() {
                  _inputMode = mode;
                });
              },
              onTogglePanel: () {
                manager.togglePanelState();
                _requestText();
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
          _hebrewGreekPanelKey.currentState?.refreshFromSettings();
          _biblePanelKey.currentState?.refreshFromSettings();
        },
      ),
      body: Stack(
        children: [
          // The main content (Bible Panels)
          Listener(
            onPointerDown: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              // Close keypad if tapping outside
              if (_inputMode != ReferenceInputMode.none) {
                _chooserKey.currentState?.resetAll();
              }
            },
            behavior: HitTestBehavior.translucent,
            child: NotificationListener<VerseNumberTapNotification>(
              onNotification: (notification) {
                if (manager.audioManager.isVisibleNotifier.value) {
                  manager.audioManager.play(
                    checkBookId: notification.bookId,
                    checkChapter: notification.chapter,
                    checkBookName: bookNameFromId(context, notification.bookId),
                    startVerse: notification.verse,
                  );
                }
                return true;
              },
              child: ValueListenableBuilder<bool>(
                valueListenable: manager.isSinglePanelNotifier,
                builder: (context, isSinglePanel, _) {
                  return Column(
                    children: [
                      Expanded(
                        child: HebrewGreekPanel(
                          key: _hebrewGreekPanelKey,
                          bookId: _jumpBookId,
                          chapter: _jumpChapter,
                          syncController: syncController,
                        ),
                      ),
                      if (!isSinglePanel) ...[
                        const Divider(height: 0, indent: 8, endIndent: 8),
                        Expanded(
                          child: BiblePanel(
                            key: _biblePanelKey,
                            bookId: _jumpBookId,
                            chapter: _jumpChapter,
                            syncController: syncController,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          // The Audio Player sliding up from the bottom
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

          // The Numeric Keypad
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
                elevation: 16, // Add shadow so it stands out
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

  /// Handles explicit user navigation (selecting from menus)
  void _onUserNavigation(int bookId, int chapter, int verse) {
    manager.saveBookAndChapter(bookId, chapter);
    manager.updateReference(bookId, chapter, verse);

    setState(() {
      _jumpBookId = bookId;
      _jumpChapter = chapter;
    });

    manager.onBookSelected(context, bookId);
    _requestText();
  }

  void _requestText() {
    if (manager.isSinglePanelNotifier.value) return;
    manager.requestText();
  }

  void _scrollToVerse(int verse) {
    syncController.jumpToVerse(
      manager.currentBookId,
      manager.currentChapter,
      verse,
    );
  }

  Future<void> _onPlayAudio(BuildContext context) async {
    // If already open, close it (Toggle behavior)
    if (manager.audioManager.isVisibleNotifier.value) {
      manager.audioManager.stopAndClose();
      return;
    }

    final bookId = manager.currentBookId;
    final chapter = manager.currentChapter;
    final verse = manager.currentVerse;

    // Check if audio is actually available for this book/chapter
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
      // Catch the specific missing audio error
      if (context.mounted) {
        _showDownloadAudioDialog(context);
      }
    } catch (e) {
      // Handle other errors
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

    // Check mounted before showing the next dialog
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

      // Check mounted again after the async dialog closes
      if (!mounted) return;

      _onPlayAudio(context);
    } catch (e) {
      if (!mounted) return;

      // Ignore cancel exceptions, show errors for everything else
      if (e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Download error: $e")));
      }
    }
  }
}
