import 'package:flutter/material.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/ui/download/resource_section.dart';

class DownloadManagerPage extends StatefulWidget {
  const DownloadManagerPage({super.key});

  @override
  State<DownloadManagerPage> createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  final _resourceService = getIt<ResourceService>();
  final _settings = getIt<UserSettings>();

  bool _refreshing = false;
  List<ResourceLanguage> _languages = [];

  String? get _selectedLang => _settings.downloadLang;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final languages = await _resourceService.getLanguages();
    if (!mounted) return;

    final selected = _selectedLang;
    final missingSelected = languages.isNotEmpty &&
        selected != null &&
        !languages.any((l) => l.code == selected);
    if (missingSelected) {
      await _settings.setDownloadLang(null);
    }

    if (!mounted) return;
    setState(() => _languages = languages);
  }

  Future<void> _refreshResources() async {
    setState(() => _refreshing = true);
    try {
      await _resourceService.refresh();
      await _loadLanguages();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _setSelectedLang(String? code) async {
    await _settings.setDownloadLang(code);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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
      body: Column(
        children: [
          if (_languages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedLang,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.language,
                    color: colorScheme.primary,
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.allLanguages),
                  ),
                  ..._languages.map(
                    (language) => DropdownMenuItem<String?>(
                      value: language.code,
                      child: Text(language.name),
                    ),
                  ),
                ],
                onChanged: _setSelectedLang,
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                ResourceSection(
                    resourceType: ResourceType.gloss,
                    title: l10n.glosses,
                    icon: Icons.translate,
                    langCode: _selectedLang,
                ),
                ResourceSection(
                    resourceType: ResourceType.bible,
                    title: l10n.bibles,
                    icon: Icons.book,
                    langCode: _selectedLang,
                ),
                ResourceSection(
                    resourceType: ResourceType.audio,
                    title: l10n.audio,
                    icon: Icons.headphones,
                    langCode: _selectedLang,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}