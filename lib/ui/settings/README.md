# Settings

## Overview
Provides application settings configuration screens and modular setting sections for application language, interlinear gloss language, Bible translation, theme mode, verse paragraph layout, and typography font scales.

## Interface
- `settings_page.dart:SettingsPage`: Main settings view aggregating configuration sections into a scrollable list.
- `section_bible.dart:BibleSection`: Section displaying and updating the active secondary Bible translation.
- `section_font_size.dart:FontSizeSection`: Expandable section providing slider dialogs to adjust Hebrew, Greek, Bible translation, and lexicon font sizes.
- `section_gloss_language.dart:GlossLanguageSection`: Section selecting interlinear gloss languages with automated download verification.
- `section_gloss_language.dart:GlossLanguageOption`: Model holding gloss resource identifier and display title.
- `section_language.dart:LanguageSection`: Section choosing application localization language.
- `section_theme.dart:ThemeSection`: Section configuring light, dark, or system default themes.
- `section_verse_layout.dart:VerseLayoutSection`: Section toggling paragraph vs. verse-per-line Scripture text flow.

## Invariants
- Font size sliders restrict scale values within the range of 10 to 60.
- If a chosen gloss language fails download or verification, selection rolls back to the previous language code.

## Side Effects
- Updates persisted configuration in `UserSettings`.
- Updates app theme state in `AppState.updateThemeMode`.
- Downloads missing resources via `ResourceUIHelper.ensureResource`.
- Displays modal dialogs for selection and slider preview.

## Verification
- Run: `flutter test`
