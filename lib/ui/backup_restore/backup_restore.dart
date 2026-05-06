import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:studyapp/l10n/app_localizations.dart';
import 'package:studyapp/services/reading_session/rs_database.dart';
import 'package:studyapp/services/reading_session/rs_manager.dart';
import 'package:studyapp/services/service_locator.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestoreState();
}

class _BackupRestoreState extends State<BackupRestorePage> {
  final _readingSessionManager = getIt<ReadingSessionManager>();
  PackageInfo? _packageInfo;
  List<ReadingSessionBackupInfo> _backups = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final backups = await _readingSessionManager.listBackups();
    if (!mounted) return;
    setState(() {
      _packageInfo = packageInfo;
      _backups = backups;
    });
  }

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
    });

    try {
      final path = await _readingSessionManager.createBackup();
      await _loadPageData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupCreated(path))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
    });

    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final bytes = await _readingSessionManager.buildBackupBytes();
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.chooseBackupLocation,
        fileName: 'reading_session_$timestamp.json',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (targetPath == null) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupExported(targetPath))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.selectBackupFile,
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final label = file.name;

      if (file.path != null) {
        await _readingSessionManager.restoreBackup(file.path!);
      } else if (file.bytes != null) {
        await _readingSessionManager.restoreBackupBytes(file.bytes!);
      } else {
        throw FileSystemException(l10n.couldNotReadSelectedBackupFile);
      }

      await _loadPageData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupImported(label))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _restoreBackup(ReadingSessionBackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreBackupQuestion),
        content: Text(l10n.restoreBackupConfirmation(backup.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _readingSessionManager.restoreBackup(backup.path);
      await _loadPageData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupRestored(backup.name))));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupRestore)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_packageInfo != null)
            Text(
              l10n.appVersion(_packageInfo!.version, _packageInfo!.buildNumber),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _createBackup,
            icon: const Icon(Icons.backup_outlined),
            label: Text(l10n.createReadingSessionBackup),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _exportBackup,
            icon: const Icon(Icons.upload_file),
            label: Text(l10n.exportToFilesDrive),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importBackup,
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(l10n.importFromFilesDrive),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.backupSystemPickerHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.savedBackups,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noBackupsCreatedYet),
            ),
          ..._backups.map(
            (backup) => Card(
              child: ListTile(
                title: Text(backup.name),
                subtitle: Text(
                  '${_formatDateTime(backup.modifiedAt)} • ${l10n.bytesCount(backup.sizeBytes)}',
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _restoreBackup(backup),
                  child: Text(l10n.restore),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
