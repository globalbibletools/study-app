import 'package:gbt/services/logging/log.dart';

import 'package:material_ui/material_ui.dart';
import 'package:gbt/l10n/app_localizations.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/ui/common/resource_ui_helper.dart';

class GlossLanguageSection extends StatefulWidget {
  const GlossLanguageSection({super.key});

  @override
  State<GlossLanguageSection> createState() => _GlossLanguageSectionState();
}

class _GlossLanguageSectionState extends State<GlossLanguageSection> {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  List<GlossLanguageOption> glossResources = [];

  @override
  void initState() {
    super.initState();
    _initGlossResources();
  }

  Future<void> _initGlossResources() async {
    try {
      final resources = await _resourceService.getResourcesByType(
        ResourceType.gloss,
      );
      setState(() {
        glossResources = resources
            .map(
              (resource) =>
                  GlossLanguageOption(resource.id, resource.resourceName),
            )
            .toList();
      });
    } catch (err, stack) {
      error(
        'Failed to initialize gloss resources',
        error: err,
        stackTrace: stack,
      );
    }
  }

  String? get currentGlossLangCode => _settings.glossLang;

  String? get currentGlossLangName {
    final code = currentGlossLangCode;
    if (code == null) return null;

    try {
      return glossResources.firstWhere((r) => r.id == code).name;
    } catch (err) {
      return null;
    }
  }

  Future<void> setGlossLang(String? code) async {
    await _settings.setGlossLang(code);
    setState(() {});
  }

  Future<void> _chooseGlossLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final previousCode = currentGlossLangCode;

    final selected = await showDialog<GlossLanguageOption>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.glossLanguage),
          children: glossResources.map((resource) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, resource),
                child: Text(resource.name, style: textStyle),
              );
            }).toList(),
        );
      },
    );

    if (selected == null || selected.id == previousCode) return;

    await setGlossLang(selected.id);

    if (!mounted) return;

    await ResourceUIHelper.ensureResource(
      context,
      ResourceType.gloss,
      selected.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      title: Text(l10n.glossLanguage),
      trailing: Text(
        currentGlossLangName ?? l10n.notSet,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      onTap: () {
        _chooseGlossLanguage();
      },
    );
  }
}

class GlossLanguageOption {
  String id;
  String name;

  GlossLanguageOption(this.id, this.name);
}
