import 'dart:ui';

class LanguageConfig {
  final String code; // Flutter Locale code (e.g., 'es')
  final String nativeName; // For UI selection (e.g., 'Español')

  const LanguageConfig({
    required this.code,
    required this.nativeName,
  });
}

class AppLanguages {
  /// THE CENTRAL LIST OF SUPPORTED LANGUAGES
  static const List<LanguageConfig> supported = [
    // English (Default/Internal)
    LanguageConfig(
      code: 'en',
      nativeName: 'English',
    ),

    // Spanish
    LanguageConfig(
      code: 'es',
      nativeName: 'Español',
    ),

    // French
    LanguageConfig(
      code: 'fr',
      nativeName: 'Français',
    ),

    // Portuguese
    LanguageConfig(
      code: 'pt',
      nativeName: 'Português',
    ),

    // Arabic
    LanguageConfig(
      code: 'ar',
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
