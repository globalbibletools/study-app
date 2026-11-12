import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/reading_session/reading_plan_backup_service.dart';
import 'package:gbt/ui/home/reading_plan/reading_session_view_model.dart';
import 'package:gbt/services/service_locator.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestoreState();
}

class _BackupRestoreState extends State<BackupRestorePage> {
  final _sessionViewModel = getIt<ReadingSessionViewModel>();
  final _backupService = getIt<ReadingPlanBackupService>();
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
    final backups = await _backupService.listBackups();
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
      final path = await _backupService.createBackup();
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
      final bytes = await _backupService.buildBackupBytes();
      final targetUri = await FilePicker.saveFile(
        dialogTitle: l10n.chooseBackupLocation,
        fileName: 'reading_session_$timestamp.json',
        bytes: bytes,
        mimeType: 'application/json',
      );

      if (targetUri == null) {
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupExported(targetUri.path))),
      );
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
      final files = await FilePicker.pickFiles(
        dialogTitle: l10n.selectBackupFile,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty) {
        return;
      }

      final file = files.single;
      final label = file.name;

      if (file.path != null) {
        await _restoreDatabase(() => _backupService.restoreBackup(file.path!));
      } else {
        final bytes = await file.readAsBytes();
        await _restoreDatabase(() => _backupService.restoreBackupBytes(bytes));
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

  Future<void> _restoreDatabase(Future<void> Function() restore) async {
    await _sessionViewModel.resetForDatabaseRestore();
    await restore();
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
      await _restoreDatabase(() => _backupService.restoreBackup(backup.path));
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
