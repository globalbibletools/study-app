import 'package:flutter/material.dart';
import 'package:studyapp/common/bible_navigation.dart';
import 'package:studyapp/common/book_name.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/resources/remote_asset_service.dart';
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

  // --- AUDIO SECTION ---

  // Independent state for both Testaments
  AudioSourceType _selectedOtSource = AudioSourceType.rdb;
  AudioSourceType _selectedNtSource = AudioSourceType.tk;

  Widget _buildAudioSection(BuildContext context, AppLocalizations l10n) {
    return ExpansionTile(
      key: const PageStorageKey('audio_section_main'),
      leading: const Icon(Icons.headphones),
      title: Text(l10n.audio),
      initiallyExpanded: true,
      children: [
        // ==========================================
        // OLD TESTAMENT
        // ==========================================
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
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary,
                ),
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
                selected: {_selectedOtSource},
                onSelectionChanged: (Set<AudioSourceType> newSelection) {
                  setState(() {
                    _selectedOtSource = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),

        // Old Testament Books (1-39)
        ...List.generate(39, (index) {
          final bookId = index + 1;

          // Hide specific OT books if RDB is selected and missing entirely
          if (_selectedOtSource == AudioSourceType.rdb &&
              !AudioLogic.isRdbAvailableForBook(bookId)) {
            return const SizedBox.shrink();
          }

          return _BookDownloadTile(
            key: PageStorageKey("book_${bookId}_$_selectedOtSource"),
            bookId: bookId,
            sourceType: _selectedOtSource,
          );
        }),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(height: 32),
        ),

        // ==========================================
        // NEW TESTAMENT
        // ==========================================
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.newTestament,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AudioSourceType>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary,
                ),
                segments: [
                  ButtonSegment(
                    value: AudioSourceType.tk,
                    label: Text(l10n.sourceTK),
                  ),
                  ButtonSegment(
                    value: AudioSourceType.jh,
                    label: Text(l10n.sourceJH),
                  ),
                ],
                selected: {_selectedNtSource},
                onSelectionChanged: (Set<AudioSourceType> newSelection) {
                  setState(() {
                    _selectedNtSource = newSelection.first;
                  });
                },
              ),
            ],
          ),
        ),

        // New Testament Books (40-66)
        ...List.generate(27, (index) {
          final bookId = index + 40;

          // Hide specific NT books if JH is selected and missing
          if (_selectedNtSource == AudioSourceType.jh &&
              !AudioLogic.isJhAvailableForBook(bookId)) {
            return const SizedBox.shrink();
          }

          return _BookDownloadTile(
            key: PageStorageKey("book_${bookId}_$_selectedNtSource"),
            bookId: bookId,
            sourceType: _selectedNtSource,
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _BookDownloadTile extends StatefulWidget {
  final int bookId;
  final AudioSourceType sourceType;

  const _BookDownloadTile({
    super.key,
    required this.bookId,
    required this.sourceType,
  });

  @override
  State<_BookDownloadTile> createState() => _BookDownloadTileState();
}

class _BookDownloadTileState extends State<_BookDownloadTile> {
  final _fileService = getIt<FileService>();
  final _downloadService = getIt<DownloadService>();
  final _assetService = getIt<RemoteAssetService>();

  late Future<List<int>> _missingChaptersFuture;
  late int _totalChapters;

  @override
  void initState() {
    super.initState();
    _totalChapters = BibleNavigation.getChapterCount(widget.bookId);
    _missingChaptersFuture = _checkMissingChapters();
  }

  @override
  void didUpdateWidget(_BookDownloadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceType != widget.sourceType) {
      _reload();
    }
  }

  Future<List<int>> _checkMissingChapters() async {
    final missing = <int>[];

    for (int c = 1; c <= _totalChapters; c++) {
      if (!AudioLogic.isAudioAvailable(widget.bookId, c)) continue;

      final recId = AudioLogic.getRecordingId(
        widget.bookId,
        c,
        widget.sourceType,
      );

      final asset = _assetService.getAudioChapterAsset(
        bookId: widget.bookId,
        chapter: c,
        recordingId: recId,
      );

      if (asset == null) continue;

      final exists = await _fileService.checkFileExists(
        asset.fileType,
        asset.localRelativePath,
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
    final recId = AudioLogic.getRecordingId(
      widget.bookId,
      chapter,
      widget.sourceType,
    );
    final asset = _assetService.getAudioChapterAsset(
      bookId: widget.bookId,
      chapter: chapter,
      recordingId: recId,
    );

    if (asset == null) return;

    try {
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          await _downloadService.downloadAsset(
            asset: asset,
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
    final recId = AudioLogic.getRecordingId(
      widget.bookId,
      chapter,
      widget.sourceType,
    );
    final asset = _assetService.getAudioChapterAsset(
      bookId: widget.bookId,
      chapter: chapter,
      recordingId: recId,
    );

    if (asset != null) {
      await _fileService.deleteFile(asset.fileType, asset.localRelativePath);
      _reload();
    }
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
      for (int c = 1; c <= _totalChapters; c++) {
        final recId = AudioLogic.getRecordingId(
          widget.bookId,
          c,
          widget.sourceType,
        );

        final asset = _assetService.getAudioChapterAsset(
          bookId: widget.bookId,
          chapter: c,
          recordingId: recId,
        );
        if (asset != null) {
          await _fileService.deleteFile(
            asset.fileType,
            asset.localRelativePath,
          );
        }
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
      if (!mounted) throw Exception('Context not mounted');
      await DownloadProgressDialog.show(
        context: context,
        task: (progress, cancelToken) async {
          final total = missingChapters.length;

          for (int i = 0; i < total; i++) {
            if (cancelToken.isCancelled) throw DownloadCanceledException();

            final chapter = missingChapters[i];

            final recId = AudioLogic.getRecordingId(
              widget.bookId,
              chapter,
              widget.sourceType,
            );

            final asset = _assetService.getAudioChapterAsset(
              bookId: widget.bookId,
              chapter: chapter,
              recordingId: recId,
            );

            if (asset == null) continue;

            await _downloadService.downloadAsset(
              asset: asset,
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
  }
}
