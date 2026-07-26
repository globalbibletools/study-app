import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/ui/download/section_audio.dart';
import 'package:gbt/ui/download/section_glosses.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final _resourceService = getIt<ResourceService>();
  bool _refreshing = false;

  Future<void> _refreshResources() async {
    setState(() => _refreshing = true);
    try {
      await _resourceService.refreshResources();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloads),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _refreshResources,
          ),
        ],
      ),
      body: ListView(
        children: [
          const GlossesSection(),
          const AudioSection(),
          // _buildPlaceholderSection(l10n.bibles, Icons.book),
          // _buildPlaceholderSection(l10n.lexicons, Icons.translate),
        ],
      ),
    );
  }
}
