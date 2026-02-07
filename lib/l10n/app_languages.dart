import 'dart:ui';

class LanguageConfig {
  final String code; // Flutter Locale code (e.g., 'es')
  final String bibleFilename; // Server filename (e.g., 'spa_blm.db')
  final String glossFilename; // Server filename (e.g., 'spa.db')
  final String nativeName; // For UI selection (e.g., 'Español')

  const LanguageConfig({
    required this.code,
    required this.bibleFilename,
    required this.glossFilename,
    required this.nativeName,
  });
}

class AppLanguages {
  /// THE CENTRAL LIST OF SUPPORTED LANGUAGES
  static const List<LanguageConfig> supported = [
    // English (Default/Internal)
    LanguageConfig(
      code: 'en',
      bibleFilename: 'eng_bsb.db',
      glossFilename: 'eng.db',
      nativeName: 'English',
    ),

    // Spanish
    LanguageConfig(
      code: 'es',
      bibleFilename: 'spa_blm.db',
      glossFilename: 'spa.db',
      nativeName: 'Español',
    ),

    // French
    LanguageConfig(
      code: 'fr',
      bibleFilename: 'fra_lsg.db',
      glossFilename: 'fra.db',
      nativeName: 'Français',
    ),

    // Portuguese
    LanguageConfig(
      code: 'pt',
      bibleFilename: 'por_blj.db',
      glossFilename: 'por.db',
      nativeName: 'Português',
    ),

    // Arabic
    LanguageConfig(
      code: 'ar',
      bibleFilename: 'arb_vdv.db',
      glossFilename: 'are.db',
      nativeName: 'العربية',
    ),
  ];

  /// Helper to get config by code
  static LanguageConfig getConfig(String langCode) {
    return supported.firstWhere(
      (l) => l.code == langCode,
      // Fallback to English if not found
      orElse: () => supported.first,
    );
  }

  /// Helper for main.dart
  static List<Locale> get supportedLocales {
    return supported.map((l) => Locale(l.code)).toList();
  }
}
