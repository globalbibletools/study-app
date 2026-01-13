## 0.15.0 

- Update design of audio player to remove need for settings panel.
- Download rather than stream audio.
- Start playing audio from current verse.
- Play verse when verse number tapped (if audio player is visible).
- Fix navigation when in repeat verse audio mode.
- Fix live swapping audio voices.

## 0.14.0 - January 10, 2025

- Audio playback synced to verse numbers.
- Audio settings for repeat mode, playback speed, audio source.
- Highlight currently playing verse.
- Allow fuzzy filtering for book name navigation (remove diacritics).
- Fixed: Scrolling bottom panel doesn't update verse label.
- Fixed: Navigation to verse shows verse - 1 in verse label.
- Make reference navigation buttons less wide so they don't overflow the app bar on small phones.
- Increase the font size of the book chooser list.

## 0.13.0 - January 3, 2026

- Split screen with updated translation text layout.
- Keep scroll in sync between screens.
- New book, chapter, verse navigation.
- Infinite scroll.
- Update book, chapter, verse labels on scroll.
- Make longpress highlight time length a little longer.

## 0.12.0 - August 13, 2025

- Add "results" word to search results: No results, 1 result, 2 results (with localization support).
- Make search results count easier to see: Increase font size and brightness.
- Change button label from "See other uses" to "See uses".
- Remove Strong's code from similar verses list.
- Increased the font size of the lexical entry.
- Make the lexical gloss bold (and slightly dim the extended definition).
- Move chapter chooser dialog closer to the top.
- Allow both root search and exact search in similar verses screen.
- Add data to query Strong's code root directly rather than using lexicon estimate.
- MVP for split screen Bible translation. (BSB default)

## 0.11.0 - August 9, 2025

- Increase font size for lexicon.
- Swipe right/left to navigate between chapters.
- Add a navigation button below the text to advance to the next chapter (for those who don't know you can swipe).
- Set max width for word details dialog (helpful for large screens).
- Add a close button to the word details dialog (helpful when dialog fills screen on small devices).
- Highlight the long-pressed word for a little while after the dialog closes so that users don't lose their place.
- Fix lexicon bug where entries with multiple names were incorrectly parsed.
- Remove arrows (► and ◄) from lexicon entries.
- Fix pinch-to-zoom focal point.

## 0.10.0 - August 7, 2025

- Add semantic dictionaries for Hebrew and Greek (visible on word long press).
- Change style of part of speech popup (in front of content instead of over it).
- Add a second way to change the text size (in settings).
- Improve font size in language change settings.
- Fix text directionality for similar verses page.
- Show root word on similar verses page.
- Fix iOS launcher icon title (GBT, not Studyapp)
- Update the app namespace to com.globalbibletools.gbt.

## 0.9.1 - July 30, 2025

- Localize missing phrase into Spanish.
- Ensure that button text doesn't line wrap on About page.
- Add search button next to text input box.
- Add system vs in-app keyboard switcher button to app bar on Search page.
- System keyboard shows search button.
- Move search candidate words (auto-complete suggestions) to in-app keyboard candidate list (show max three).
- Candidate words are based on word frequency in the text. Higher frequency words are returned first. No suggestions means the current input does not exist in the text.

## 0.8.0 - July 24, 2025

- Fix text size and line wrapping problems on word longpress dialog.
- Improve list view of Strong's code verses: better size and scrolling.
- Fuzzy search (no diacritics) for Hebrew and Greek.
- Multi-word search.
- In-app Hebrew keyboard for search.
- In-app Greek keyboard for search.
- Auto handling of final Hebrew and Greek forms when typing.

## 0.7.0 - July 22, 2025

- Improve presentation when word is long pressed.
- Show grammar explanation when grammar type tapped.
- Show all verses that use a Strongs' code.

## 0.6.0 - July 14, 2025

- Show lemma (Strong's number) and grammar abbreviation when word is long pressed.

## 0.5.3 - June 25, 2025

- Fix Spanish localization errors.

## 0.5.2 - June 24, 2025

- Add multilingual support with Spanish test case.
- Download Spanish gloss database.
- Add about screen.
- Change launcher icon title to "GBT".
- Upgrade Flutter to 3.32.4.

## 0.4.0 - June 17, 2025

- Rewrite the text layout implementation to be more performant and customizable.
- Style the verse numbers.
- Fix the pinch to zoom.
- Move popup when scrolling.
- Scroll to put the popup in view when hidden under the app bar.
- Fix popup near edges getting cut off.

## 0.3.5 - June 13, 2025

- Add verse numbers.
- Fix Font for Linux (#13) (@omarandlorraine)
- Pinch to change font size.
- Remove drawer menu for now.
- Fix maqaph spacing issue.
- Fix popup disappearing too quickly when tapping multiple words.
- Make popup show for 3 seconds.
- Make background black and text white.

## 0.2.0 - June 10, 2025

- Show English gloss popup when tapping a word.

## 0.1.0 - May 29, 2025

- Full Hebrew/Greek text navigable.