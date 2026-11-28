import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/logging/app_logger.dart';
import 'package:gbt/services/logging/log.dart';
import 'package:gbt/services/logging/log_exporter.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/messaging/messenger_view_model.dart';

class ExportLogsButton extends StatelessWidget {
  ExportLogsButton({super.key});

  final _messenger = getIt<MessengerViewModel>();
  final _logger = getIt<AppLogger>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: OutlinedButton.icon(
        onPressed: () => _exportLogs(context),
        icon: const Icon(Icons.archive_outlined),
        label: Text(l10n.exportLogs),
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      await _logger.flush();
      final now = DateTime.now();
      final exporter = await LogExporter.createDefault();

      final bytes = await exporter.getExportAsBytes(now: now);
      if (bytes.isEmpty) {
        _messenger.showWarning(l10n.noLogsToExport);
        return;
      }

      final targetUri = await FilePicker.saveFile(
        dialogTitle: l10n.chooseLogLocation,
        fileName: LogExporter.exportFileNameForDate(now),
        bytes: bytes,
        mimeType: 'application/zip',
      );

      if (targetUri == null) {
        return;
      }

      _messenger.showSuccess(l10n.logsExported);
    } catch (e, stackTrace) {
      error('Failed to export logs', error: e, stackTrace: stackTrace);
      _messenger.showError(l10n.logExportFailed);
    }
  }
}
