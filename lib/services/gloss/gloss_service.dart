import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  GlossDatabase? _db;
  String? _currentLangCode;

  Future<void> init() async {
    // English ships bundled in the app assets. Seed it into the same on-disk
    // location used for downloaded glosses so it's treated uniformly.
    await _resourceService.seedBundledResource(ResourceType.Gloss, 'eng');
  }

  Future<bool> glossesExists(String langCode) async {
    return _resourceService.resourceExists(ResourceType.Gloss, langCode);
  }

  Future<String?> glossForId({
    required int wordId,
    void Function(String)? onDatabaseMissing,
  }) async {
    final langCode = _settings.glossLang;

    // No gloss language chosen yet — there is nothing to look up.
    if (langCode == null) return null;

    // Ensure the active database matches the current language.
    if (_currentLangCode != langCode) {
      try {
        await _openForLang(langCode);
      } on ResourceMissingException {
        onDatabaseMissing?.call(langCode);
        return null;
      }
    }

    return _db!.getGloss(wordId);
  }

  Future<void> _openForLang(String langCode) async {
    // Already the active database.
    if (_currentLangCode == langCode && _db != null) return;

    final path = await _resourceService.getResourceLocalPath(
      ResourceType.Gloss,
      langCode,
    );

    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentLangCode = null;
    }

    _db = await GlossDatabase.open(path);
    _currentLangCode = langCode;
  }
}
