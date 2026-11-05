# Localization

## Overview
Provides internationalization and localization (l10n) assets, generated delegates, supported locale configurations, and multilingual book title resolution. Houses ARB translation templates for English, Spanish, French, Portuguese, and Arabic, alongside utilities to resolve original language script titles and app language configurations.

## Interface
- [app_languages.dart:LanguageConfig]: Value model encapsulating ISO locale code and native display name.
- [app_languages.dart:AppLanguages]: Registry of active application languages (`supported`), locale list builder (`supportedLocales`), and safe configuration lookup with default fallback (`getConfig`).
- [book_names.dart:bookNameFromId]: Resolves localized book name from the ambient `BuildContext` and canonical book ID.
- [book_names.dart:bookNameFromLocalizations]: Maps canonical book ID (1..66) to localized string using an explicit `AppLocalizations` instance.
- [book_names.dart:orgBookNameFromId]: Returns the original Hebrew/Aramaic or Greek name string for canonical book IDs 1 through 66.
- [app_localizations.dart:AppLocalizations]: Generated base contract and localization delegate defining string accessors across all supported languages.
- [app_localizations_ar.dart:AppLocalizationsAr]: Generated Arabic localization implementation.
- [app_localizations_en.dart:AppLocalizationsEn]: Generated English localization implementation.
- [app_localizations_es.dart:AppLocalizationsEs] Generated Spanish localization implementation.
- [app_localizations_fr.dart:AppLocalizationsFr]: Generated French localization implementation.
- [app_localizations_pt.dart:AppLocalizationsPt]: Generated Portuguese localization implementation.

## Invariants
- `AppLanguages.getConfig` safely falls back to English (`supported.first`) if an unknown or unsupported language code is provided.
- `bookNameFromLocalizations` and `orgBookNameFromId` return an empty string `""` for any book ID outside the canonical range 1..66.
- Application-wide supported language codes are restricted to `en`, `es`, `fr`, `pt`, and `ar`.
- ARB dictionary keys in `app_*.arb` files must match the generated interface properties in `AppLocalizations`.

## Side Effects
- None

## Verification
- Run: `flutter test`
