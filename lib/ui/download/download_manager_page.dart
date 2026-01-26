import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/audio/audio_url_helper.dart';
import 'package:studyapp/services/download/cancel_token.dart';
import 'package:studyapp/services/download/download.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';
import 'package:studyapp/ui/common/download_progress_dialog.dart';
import 'package:studyapp/ui/home/audio/audio_logic.dart';
import 'package:studyapp/ui/home/audio/audio_manager.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  // We use this to rebuild the UI when downloads finish
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloads)),
      body: ListView(
        children: [
          _buildAudioSection(context, l10n),
          // _buildPlaceholderSection(l10n.bibles, Icons.book),
          // _buildPlaceholderSection(l10n.lexicons, Icons.translate),
        ],
      ),
    );
  }

  // Widget _buildPlaceholderSection(String title, IconData icon) {
  //   return ExpansionTile(
  //     leading: Icon(icon),
  //     title: Text(title),
  //     children: const [ListTile(title: Text("Coming soon..."), enabled: false)],
  //   );
  // }

  // --- AUDIO SECTION ---

  // Default to Dan Beeri as requested
  AudioSourceType _selectedSource = AudioSourceType.rdb;

  Widget _buildAudioSection(BuildContext context, AppLocalizations l10n) {
    return ExpansionTile(
      leading: const Icon(Icons.headphones),
      title: Text(l10n.audio),
      initiallyExpanded: true,
      children: [
        // Source Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.oldTestament,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AudioSourceType>(
                segments: [
                  ButtonSegment(
                    value: AudioSourceType.rdb,
                    label: Text(l10n.sourceRDB),
                  ),
                  ButtonSegment(
                    value: AudioSourceType.heb,
                    label: Text(l10n.sourceHEB),
                  ),
                ],
                selected: {_selectedSource},
                onSelectionChanged: (Set<AudioSourceType> newSelection) {
                  setState(() {
                    _selectedSource = newSelection.first;
                    _refreshKey++; // Reload list status
                  });
                },
              ),
            ],
          ),
        ),

        // Book List
        ...List.generate(66, (index) {
          final bookId = index + 1;

          // Filter out books that have NO audio at all
          bool hasAnyAudio =
              !AudioLogic.isNewTestament(bookId) ||
              AudioLogic.isAudioAvailable(bookId, 1);

          // Specific check for RDB missing books (Hide them if RDB is selected)
          if (_selectedSource == AudioSourceType.rdb &&
              !AudioLogic.isRdbAvailableForBook(bookId) &&
              !AudioLogic.isNewTestament(bookId)) {
            return const SizedBox.shrink();
          }

          if (!hasAnyAudio) return const SizedBox.shrink();

          return _BookDownloadTile(
            key: ValueKey("${bookId}_${_selectedSource}_$_refreshKey"),
            bookId: bookId,
            sourceType: _selectedSource,
            onChanged: () => setState(() => _refreshKey++),
          );
        }),
      ],
    );
  }
}

class _BookDownloadTile extends StatefulWidget {
  final int bookId;
  final AudioSourceType sourceType;
  final VoidCallback onChanged;

  const _BookDownloadTile({
    super.key,
    required this.bookId,
    required this.sourceType,
    required this.onChanged,
  });

  @override
  State<_BookDownloadTile> createState() => _BookDownloadTileState();
}

class _BookDownloadTileState extends State<_BookDownloadTile> {
  final _fileService = getIt<FileService>();
  final _downloadService = getIt<DownloadService>();

  late Future<List<int>> _missingChaptersFuture;
  late int _totalChapters;

  @override
  void initState() {
    super.initState();
    _totalChapters = BibleNavigation.getChapterCount(widget.bookId);
    _missingChaptersFuture = _checkMissingChapters();
  }

  Future<List<int>> _checkMissingChapters() async {
    final missing = <int>[];
    for (int c = 1; c <= _totalChapters; c++) {
      if (!AudioLogic.isAudioAvailable(widget.bookId, c)) continue;

      final recId = AudioLogic.getRecordingId(widget.bookId, widget.sourceType);
      final relPath = AudioUrlHelper.getLocalRelativePath(
        bookId: widget.bookId,
        chapter: c,
        recordingId: recId,
      );
      final exists = await _fileService.checkFileExists(
        FileType.audio,
        relPath,
      );
      if (!exists) missing.add(c);
    }
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<int>>(
      future: _missingChaptersFuture,
      builder: (context, snapshot) {
        final missing = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final allDownloaded = missing.isEmpty && !isLoading;

        return ExpansionTile(
          // Indentation for Book Name (Level 1)
          tilePadding: const EdgeInsets.only(left: 32, right: 16),
          title: Text(bookNameForId(context, widget.bookId)),
          subtitle: isLoading
              ? const Text("...")
              : Text("${_totalChapters - missing.length} / $_totalChapters"),
          trailing: IconButton(
            icon: Icon(allDownloaded ? Icons.delete : Icons.download),
            color: primaryColor,
            onPressed: isLoading
                ? null
                : () {
                    if (allDownloaded) {
                      _confirmDeleteBook(l10n);
                    } else {
                      _confirmDownloadBook(missing, l10n);
                    }
                  },
          ),
          children: [
            if (!isLoading)
              ...List.generate(_totalChapters, (index) {
                final chapter = index + 1;
                if (!AudioLogic.isAudioAvailable(widget.bookId, chapter)) {
                  return const SizedBox.shrink();
                }

                final isMissing = missing.contains(chapter);

                return ListTile(
                  // Indentation for Chapter Name (Level 2)
                  contentPadding: const EdgeInsets.only(left: 64, right: 16),
                  title: Text(
                    "${bookNameForId(context, widget.bookId)} $chapter",
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isMissing
                          ? Icons.download_outlined
                          : Icons.delete_outline,
                    ),
                    color: primaryColor,
                    onPressed: () {
                      if (isMissing) {
                        _downloadChapter(chapter);
                      } else {
                        _deleteChapter(chapter);
                      }
                    },
                  ),
                  onTap: () {
                    if (isMissing) {
                      _downloadChapter(chapter);
                    } else {
                      _deleteChapter(chapter);
                    }
                  },
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _downloadChapter(int chapter) async {
    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          final recId = AudioLogic.getRecordingId(
            widget.bookId,
            widget.sourceType,
          );
          final url = AudioUrlHelper.getAudioUrl(
            bookId: widget.bookId,
            chapter: chapter,
            recordingId: recId,
          );
          final relPath = AudioUrlHelper.getLocalRelativePath(
            bookId: widget.bookId,
            chapter: chapter,
            recordingId: recId,
          );

          await _downloadService.downloadFile(
            url: url,
            type: FileType.audio,
            relativePath: relPath,
            onProgress: (p) => progress.value = p,
            cancelToken: cancelToken,
          );
        },
      );
      _reload();
    } catch (e) {
      if (mounted && e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deleteChapter(int chapter) async {
    final recId = AudioLogic.getRecordingId(widget.bookId, widget.sourceType);
    final relPath = AudioUrlHelper.getLocalRelativePath(
      bookId: widget.bookId,
      chapter: chapter,
      recordingId: recId,
    );
    await _fileService.deleteFile(FileType.audio, relPath);
    _reload();
  }

  Future<void> _confirmDeleteBook(AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(
          l10n.deleteAudioConfirmation(bookNameForId(context, widget.bookId)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final recId = AudioLogic.getRecordingId(widget.bookId, widget.sourceType);
      for (int c = 1; c <= _totalChapters; c++) {
        final relPath = AudioUrlHelper.getLocalRelativePath(
          bookId: widget.bookId,
          chapter: c,
          recordingId: recId,
        );
        await _fileService.deleteFile(FileType.audio, relPath);
      }
      _reload();
    }
  }

  Future<void> _confirmDownloadBook(
    List<int> missingChapters,
    AppLocalizations l10n,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // title: const Text("Download All?"),
        content: Text(
          l10n.downloadAudioConfirmation(
            missingChapters.length,
            bookNameForId(context, widget.bookId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.download),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          final total = missingChapters.length;
          final recId = AudioLogic.getRecordingId(
            widget.bookId,
            widget.sourceType,
          );

          for (int i = 0; i < total; i++) {
            if (cancelToken.isCancelled) throw DownloadCanceledException();

            final chapter = missingChapters[i];

            final url = AudioUrlHelper.getAudioUrl(
              bookId: widget.bookId,
              chapter: chapter,
              recordingId: recId,
            );
            final relPath = AudioUrlHelper.getLocalRelativePath(
              bookId: widget.bookId,
              chapter: chapter,
              recordingId: recId,
            );

            await _downloadService.downloadFile(
              url: url,
              type: FileType.audio,
              relativePath: relPath,
              cancelToken: cancelToken,
              onProgress: (fileProgress) {
                final overall = (i / total) + (fileProgress / total);
                progress.value = overall;
              },
            );
          }
        },
      );
    } catch (e) {
      if (mounted && e is! DownloadCanceledException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      _missingChaptersFuture = _checkMissingChapters();
    });
    widget.onChanged();
  }
}
