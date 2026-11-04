# User Settings Service

## Overview
Manages local application preferences, UI typography font scaling, reading progress positions, active Bible translation and gloss language choices, and onboarding tutorial flags using `SharedPreferences`. Runs ordered, forward migrations during initialization.

## Interface
- [user_settings.dart:UserSettings]: Primary service exposing getters and asynchronous setters for application preferences.
- [user_settings.dart:UserSettings.init]: Asynchronously loads `SharedPreferences` and applies pending settings migrations.
- [user_settings.dart:UserSettings.themeMode] / [user_settings.dart:UserSettings.setThemeMode]: Controls theme brightness selection (`light`, `dark`, or system).
- [user_settings.dart:UserSettings.currentBookChapter] / [user_settings.dart:UserSettings.setCurrentBookChapter]: Coordinates the active Bible book and chapter position (defaults to `(1, 1)`).
- [user_settings.dart:UserSettings.baseFontSize]: Constant reference font size (`20.0`).
- [user_settings.dart:UserSettings.hebrewFontScale] / [user_settings.dart:UserSettings.setHebrewFontScale]: Text scale factor for Hebrew script.
- [user_settings.dart:UserSettings.greekFontScale] / [user_settings.dart:UserSettings.setGreekFontScale]: Text scale factor for Greek script.
- [user_settings.dart:UserSettings.bibleFontScale] / [user_settings.dart:UserSettings.setBibleFontScale]: Text scale factor for vernacular Bible text.
- [user_settings.dart:UserSettings.wordDetailsFontScale] / [user_settings.dart:UserSettings.setWordDetailsFontScale]: Text scale factor for lexicon detail views.
- [user_settings.dart:UserSettings.locale] / [user_settings.dart:UserSettings.setLocale]: Application display `Locale` (defaults to `'en'`).
- [user_settings.dart:UserSettings.hasSetLocale]: Indicates whether the user explicitly configured a display language.
- [user_settings.dart:UserSettings.glossLang] / [user_settings.dart:UserSettings.setGlossLang]: Configured target gloss language code.
- [user_settings.dart:UserSettings.currentBible] / [user_settings.dart:UserSettings.setCurrentBible]: Identifier of active modern Bible translation.
- [user_settings.dart:UserSettings.downloadLang] / [user_settings.dart:UserSettings.setDownloadLang]: Language filter code for package downloads.
- [user_settings.dart:UserSettings.isHebrewSearch] / [user_settings.dart:UserSettings.setIsHebrewSearch]: Toggles search entry mode between Hebrew and Greek.
- [user_settings.dart:UserSettings.shouldUseSystemKeyboard] / [user_settings.dart:UserSettings.setUseSystemKeyboard]: Toggles system keyboard vs built-in virtual keyboard.
- [user_settings.dart:UserSettings.verseLayout] / [user_settings.dart:UserSettings.setVerseLayout]: Controls scripture paragraph flow or line-by-line format.
- [user_settings.dart:UserSettings.hasSeenReadingSessionGuide] / [user_settings.dart:UserSettings.setHasSeenReadingSessionGuide]: Tracks reading session guide onboarding dismissal.
- [user_settings.dart:UserSettings.hasSeenReadingCheckboxGuide] / [user_settings.dart:UserSettings.setHasSeenReadingCheckboxGuide]: Tracks checkbox guide onboarding dismissal.
- [user_settings.dart:VerseLayout]: Enum defining scripture formatting (`paragraph`, `versePerLine`).
- [settings_migrations.dart:migrateSettings]: Sequential migration engine running pending migration closures against `SharedPreferences`.
- [settings_migrations.dart:migrateV1]: Migration assigning default Bible and gloss translation codes according to the UI locale.

## Invariants
- Migrations run in strictly ascending sequential order, updating `settingsVersion` in `SharedPreferences` after each step.
- Font scaling factors default to `1.0`.
- Missing book and chapter indices default to Genesis 1 (`bookId = 1, chapter = 1`).

## Side Effects
- Reads and persists configuration values using `shared_preferences`.

## Verification
- Run: `flutter test`
