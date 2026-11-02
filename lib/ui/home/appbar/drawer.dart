import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/logging/log_exporter.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/about/about.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/ui/backup_restore/backup_restore.dart';
import 'package:gbt/ui/download/download_manager_page.dart';
import 'package:gbt/ui/search/search.dart';
import 'package:gbt/ui/settings/settings_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onSettingsClosed});

  final VoidCallback onSettingsClosed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Center(
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.settings),
              leading: Icon(Icons.settings_outlined),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
                onSettingsClosed();
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.search),
              leading: Icon(Icons.search),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.downloads),
              leading: ValueListenableBuilder<OutdatedResourceCounts>(
                valueListenable:
                    getIt<ResourceService>().outdatedResourceCounts,
                builder: (context, counts, _) {
                  return Badge.count(
                    count: counts.total,
                    isLabelVisible: counts.total > 0,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.download),
                  );
                },
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadManagerPage(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.about),
              leading: Icon(Icons.info_outline),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.backupRestore),
              leading: Icon(Icons.cloud_upload),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BackupRestorePage(),
                  ),
                );
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.exportLogs),
              leading: const Icon(Icons.archive_outlined),
              onTap: () => _exportLogs(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final logger = getIt<AppLogger>();

    Navigator.pop(context);

    try {
      await logger.flush();
      final now = DateTime.now();
      final exporter = await LogExporter.createDefault();

      final bytes = await exporter.getExportAsBytes(now: now);
      if (bytes.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noLogsToExport)));
        return;
      }

      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.chooseLogLocation,
        fileName: LogExporter.exportFileNameForDate(now),
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (targetPath == null) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text(l10n.logsExported)));
    } catch (e, stackTrace) {
      error('Failed to export logs', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text(l10n.logExportFailed)));
    }
  }
}
