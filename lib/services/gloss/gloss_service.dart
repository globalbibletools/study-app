import 'package:gbt/services/gloss/gloss_database.dart';
import 'package:gbt/services/resources/resource_language.dart';
import 'package:gbt/services/resources/resource_service.dart';
import 'package:gbt/services/service_locator.dart';
import 'package:gbt/services/settings/user_settings.dart';

class GlossService {
  final _settings = getIt<UserSettings>();
  final _resourceService = getIt<ResourceService>();

  GlossDatabase? _db;
  String? _currentLangCode;
  ResourceLanguage? _currentLanguage;

  GlossService() {
    _resourceService.addResourceChangeListener(
      ResourceType.gloss,
      _onGlossResourceChanged,
    );
  }

  Future<bool> glossesExists(String langCode) async {
    return _resourceService.resourceExists(ResourceType.gloss, langCode);
  }

  Future<GlossResult?> glossForId({
    required String wordId,
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

    final textDirection =
        _currentLanguage?.textDirection ?? ResourceLanguageTextDirection.ltr;
    return _db!.getGloss(wordId, textDirection);
  }

  Future<void> _openForLang(String langCode) async {
    final path = await _resourceService.getResourceLocalPath(
      ResourceType.gloss,
      langCode,
    );
    final language = await _resourceService.getLanguageForResource(
      ResourceType.gloss,
      langCode,
    );

    await _close();

    _db = await GlossDatabase.open(path);
    _currentLangCode = langCode;
    _currentLanguage = language;
  }

  Future<void> _close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _currentLangCode = null;
      _currentLanguage = null;
    }
  }

  void _onGlossResourceChanged(ResourceType type, String id) {
    if (_currentLangCode == null || id == _currentLangCode) {
      _close();
    }
  }
}
