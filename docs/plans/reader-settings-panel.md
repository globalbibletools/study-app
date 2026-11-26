# Reader Settings Panel

- Date: 2026-11-26
- Status: Draft
- Related: [Four-Layer Architecture](../decisions/2026-11-18-four-layer-architecture.md),
  [Vertical Slices](../decisions/2026-11-19-vertical-slices.md),
  [Serialized View Model Commands](../decisions/2026-11-25-serialized-view-model-commands.md)

# Context

Gloss language and Bible translation settings are reachable only through the
drawer's full Settings page, and both are nullable today. The damaging path:
when a reader taps a word whose gloss database is missing,
`ResourceUIHelper.ensureResource` offers a generic Download/Cancel prompt,
and Cancel calls `ChapterManager.unsetGlossLang()`
(`lib/ui/home/panel_area/hebrew_greek_panel/chapter_manager.dart:87`), which
permanently sets `glossLang` to null so the prompt does not repeat. Glosses
then disappear silently, with nothing in the UI telling the user the setting
exists or where to change it. Bibles have a parallel (weaker) issue:
`currentBible` is nullable and cancellable, and the panel state
(`HomeManager.isSinglePanelNotifier`) is in-memory only.

Goal: readers never end up with glosses unintentionally off; if they turn
them off, the way back is one visible tap away and clearly signposted.

# Current behavior inventory

| Behavior | Today |
|---|---|
| Gloss/Bible settings entry | Drawer → Settings page only |
| Parallel Bible toggle | `Icons.splitscreen` appbar button → `HomeManager.togglePanelState`; in-memory `isSinglePanelNotifier` |
| No-Bible guard | `togglePanelState` forces `chooseBible()` when `currentBible == null` |
| Gloss off paths | "None" in the gloss picker; Cancel on a missing-gloss download prompt (`unsetGlossLang`) |
| Bible off paths | "None" in the Bible chooser (`allowNone`); Cancel on missing-bible prompt closes the panel |
| Defaults | `migrateV1` backfills `glossLang`/`currentBible` by UI locale (`eng`/`eng_bsb` default) |
| Download prompts | Generic `ResourceUIHelper.ensureResource`: Download / Cancel, at five call sites |
| Downloads page | Language dropdown persisted in `downloadLang`; downloads never touch reader settings |
| One-time prompts | `AppGuideManager` + `hasSeen*` SharedPreferences keys |

# Design decisions

Confirmed during planning (2026-11-26):

1. **Gear replaces the splitscreen icon.** The appbar button becomes a
   settings gear opening a bottom sheet. The one-tap panel toggle moves into
   the sheet as the "Parallel Bible" switch; there is no separate panel
   toggle on the appbar.
2. **Enabled/preference split.** Two new persisted booleans,
   `glossesEnabled` and `parallelBibleEnabled`, control whether the features
   are active. The preferences `glossLang` and `currentBible` become required
   (always set, with locale-derived defaults). Turning a feature off no
   longer destroys the preference.
3. **`parallelBibleEnabled` replaces `isSinglePanelNotifier`.** Panel
   visibility becomes a persisted setting; `togglePanelState`'s no-Bible
   guard and `notifySettingsChanged`'s "close panel when no Bible" branch
   disappear once the preference is always set.
4. **Existing "None" selections** are backfilled with the same locale-based
   default derivation as `migrateV1`, but the feature stays toggled **off**
   (respecting the opt-out; the what's-new dialog explains how to turn it
   back on).
5. **Sheet contents:** parallel Bible toggle + translation picker, glosses
   toggle + language picker, verse layout, font sizes. The full Settings
   page keeps only UI language and theme. Verse layout and font sizes live
   **only** in the sheet.
6. **Shared resource language setting.** One persisted language (the
   current `downloadLang`, possibly renamed `resourceLang`) is the filter
   default for both the downloads page and the new resource picker, and is
   updated whenever either is changed.
7. **Resource picker:** full catalog with download-state indicators,
   filtered by the shared language setting by default. Selecting a
   not-downloaded resource prompts a download first; selecting succeeds only
   after the download completes, otherwise the selection reverts.
8. **Reader download prompts** replace Cancel with "Turn glosses/parallel
   Bible off" plus instructions pointing at the gear, so the consequence of
   declining is explicit and reversible.
9. **Downloads page follow-through:** after downloading a gloss/bible,
   prompt to adopt it only when the current selection is not downloaded.
10. **What's-new:** one generic one-time dialog explaining the gear, the
    sheet, and the new resource flow. No separate gloss-off prompt (the
    migration + dialog (a) cover it).
11. **New installs:** glosses enabled, parallel Bible panel off (matches
    today's first-run: single panel, no prompts until toggled on).
12. **Out of scope:** the occurrence parallel-translations sheet
    (`lib/ui/home/word_details_dialog/similar_verses/parallel_translations_sheet.dart`)
    keeps its current flow, accepting its old-style prompts for now.

# New settings keys

| Key | Type | Default | Meaning |
|---|---|---|---|
| `glossesEnabled` | bool | `true` | gloss lookups active |
| `parallelBibleEnabled` | bool | `false` | parallel Bible panel visible |
| `glossLang` | String (required) | locale-derived (`eng`) | gloss language preference |
| `currentBible` | String (required) | locale-derived (`eng_bsb`) | parallel translation preference |
| `downloadLang` | String? | null | shared resource-language filter (downloads page + picker default) |
| `hasSeenWhatsNew` | bool | `false` | what's-new dialog shown |

# Settings migration (v2)

Following the convention in
`lib/services/settings/settings_migrations.dart` (append `migrateV2`):

- `glossLang == null` → derive from locale (the `migrateV1` map), set
  `glossesEnabled = false`.
- `glossLang != null` → `glossesEnabled = true`.
- `currentBible == null` → derive from locale, `parallelBibleEnabled = false`.
- `currentBible != null` → `parallelBibleEnabled` stays at its default
  (`false`; panel visibility was never persisted, so no existing state is
  lost).

Fresh installs already get locale preferences from `migrateV1`; the enabled
defaults above apply.

# Implementation chunks

Deliberately incremental; each chunk leaves the app fully working and
passes the standard verification
(`flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`).

## Chunk 1 — Reader settings sheet with current pickers

Build the new surface without changing any picker behavior. No settings
migration yet.

**Follow the reading-plan panel patterns** (the canonical example of the
current UI conventions):

- *Bottom sheet navigation* — `lib/reading_plan/ui/reading_sheet.dart`:
  a static `navigateTo` that constructs the view model first
  (`await ViewModel.create()`), shows `showModalBottomSheet`
  (`isScrollControlled`, `useSafeArea`, rounded top corners), wraps content
  in a fixed-height sheet body (ClipRRect + Material + SafeArea, handle bar,
  sheet-internal `Navigator` for sub-routes), and disposes the view model on
  failure or unmounted context.
- *View model* — `lib/reading_plan/ui/reading_plan_panel_view_model.dart`:
  private constructor plus a static async `create()` factory taking optional
  injected dependencies (getIt defaults inside `create`, not field
  initializers), `ChangeNotifier`, commands serialized through `SerialQueue`
  (`runCoalesced` for fast idempotent ones), `_setState` guarded by
  `_disposed`, and a dispose path that closes the queue before
  `super.dispose()`.
- *Widget construction* — `lib/reading_plan/ui/reading_plan_panel.dart`:
  the panel widget receives the view model constructed by `navigateTo`,
  subscribes with `ListenableBuilder`, and keeps l10n reads in `build`.

The sheet follows these patterns from the start: `ReaderSettingsSheet`
wraps a `ReaderSettingsViewModel` (state: the parallel-Bible toggle and
settings version), and the existing section widgets render inside it. The
section widgets themselves keep their current getIt-based shape in this
chunk; converting them to the view-model pattern is not in scope.

- New `lib/ui/home/settings/reader_settings_sheet.dart`:
  `ReaderSettingsSheet.navigateTo(context, onChanged)` following the
  ReadingSheet pattern (see above). The gloss and Bible rows keep their
  **current** pickers (the gloss SimpleDialog and `chooseBible`) for now;
  chunk 3 replaces them.
- Move the reader-facing sections from `lib/ui/settings/` to
  `lib/ui/home/settings/` (the sheet is their only consumer once the
  Settings page drops them): `section_bible.dart`,
  `section_gloss_language.dart`, `section_verse_layout.dart`,
  `section_font_size.dart`.
- `UserSettings`: add `parallelBibleEnabled` (bool, default false) and
  setter.
- `HomeManager`: panel visibility reads/writes the persisted setting instead
  of `isSinglePanelNotifier` (a `ValueNotifier` mirror keeps the widget
  contract). Turning the toggle on with `currentBible == null` runs the
  existing `chooseBible` flow; Cancel reverts to off. Reanchor the current
  reference when opening, as `togglePanelState` does today.
- Appbar (`lib/ui/home/appbar/appbar.dart`): replace the `Icons.splitscreen`
  button with a settings gear wired through `HomeManager`.
- `lib/ui/settings/settings_page.dart`: reduce to `LanguageSection` +
  `ThemeSection`.
- l10n: new strings (e.g. the parallel-Bible toggle label) in all five
  locales (en, es, fr, pt, ar).

## Chunk 2 — Settings migration and the gloss toggle

- Add `glossesEnabled`; run migration v2 (backfill rules above).
- `GlossService.glossForId` returns null immediately when glosses are
  disabled — no lookups, no prompts.
- `ChapterManager.unsetGlossLang` becomes `setGlossesEnabled(false)`; the
  missing-gloss Cancel path stops destroying the preference.
- Sheet: the gloss row becomes a toggle (on/off) plus its language picker.
- Toggle-on for either feature runs `ensureResource` when the preferred
  resource is not downloaded (existing prompt until chunk 4 reworks it).

## Chunk 3 — Resource picker sheet

- New shared picker sheet (glosses and Bibles): full catalog per the shared
  language filter, download-state indicators, download-before-select via
  `ensureResource`, revert on failure.
- Replace the chunk-1 SimpleDialog pickers in the sheet with it; remove the
  "None" options from both pickers (the toggles own off/on); delete
  `chooseBible` and the `allowNone` parameter.
- Wire the shared language setting: the picker defaults to it and updates
  it when the filter changes; the downloads page dropdown reads/writes the
  same key.

## Chunk 4 — Follow-ups

4a. **Download-prompt rework.** A `ResourceUIHelper` variant whose decline
    action is "Turn glosses/parallel Bible off" with instructions pointing
    to the gear. Applied at the reader entry points: `chapter.dart`,
    `bible_chapter.dart`, `verse_list_item.dart`.
4b. **Downloads-page follow-through.** After a gloss/bible download, prompt
    to adopt it when the current selection is not downloaded; acceptance
    writes both the preference and the enabled flag.
4c. **What's-new dialog.** One-time (`hasSeenWhatsNew`), generic explanation
    of the gear, the sheet, and download-on-select.
4d. **Cleanup and decision record.** Null-handling sweep
    (`currentBible == null` checks in `home_manager`, `bible_service`,
    `bible_chapter_manager`), dead code removal, decision record for the
    enabled/preference split, `ARCHITECTURE.md`/`AGENTS.md` touch-ups.

# Test plan

Per chunk, mirroring paths under `test/` (see `test/ui/home/` for the
existing fake-service/fake-settings patterns):

- Chunk 1: sheet renders all sections; gear opens it; parallel-Bible toggle
  persists across `HomeManager` recreation; Settings page shows only
  language + theme; toggle-on with no Bible prompts and reverts on Cancel.
- Chunk 2: migration v2 backfills and flag rules (null → derived + off; set
  → on); `GlossService` short-circuits when disabled; the Cancel path
  writes `glossesEnabled = false` and leaves `glossLang` intact.
- Chunk 3: picker lists the catalog with correct install indicators;
  filter default and write-through of the shared language setting;
  download-then-select and revert-on-cancel.
- Chunk 4: prompt copy/actions; downloads-page adoption rule; what's-new
  shows once.

# Open questions

- Should the downloads-page follow-through (4b) also prompt when the
  feature is **disabled** and the user downloads a matching resource
  (strong intent signal), or strictly when the current selection is not
  downloaded? Recommendation: also prompt when disabled.
- Should `downloadLang` be renamed (`resourceLang`) as part of chunk 3, or
  kept to avoid another migration touch?
- Does 4a's reworked prompt also cover the occurrence
  parallel-translations sheet (out of scope per decision 12), or accept the
  inconsistency until that flow is redesigned?
