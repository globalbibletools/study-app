# Design System Inventory

A survey of what this codebase already has, mapped onto atomic design
(atoms → molecules → organisms → templates → pages, all resting on a token
layer). "Defined" means it exists as reusable code today; "extractable" means
the pattern exists inline or duplicated somewhere and could be lifted into a
shared component with modest effort; "absent" appears only in the plan.

This is descriptive, not aspirational — the [plan](design-system-plan.md)
decides what to do about it.

## Tokens

### Color — partially defined, inconsistently applied

Defined in `lib/theme.dart`:

- Primary: dark theme `0xFF00BFB2` (bright teal), light theme `0xFF007F76`
  (deep teal). Two hardcoded constants, private to the file.
- Surface ramp via `ColorScheme`: dark `0xFF151515 → 0xFF484848` (5 steps),
  light `0xFFECECEC → 0xFFD4D4D4` (5 steps). This is the closest thing to a
  real token ramp in the app and is genuinely used via
  `colorScheme.surfaceContainer*` in several places.
- `onSurface`, `onPrimary` basic roles.

Defined elsewhere but outside any token system (62 raw `Color(0x…)`/`Colors.*`
references outside `theme.dart`):

- **Severity palette** in `lib/ui/messaging/messenger_host.dart` — a full
  info/success/warning/error × dark/light background/foreground/icon set
  (e.g. error dark: `0xFF4A1210`/`0xFFF87171`). A real semantic color system,
  but it lives inside one component's file as a private function.
- Keyboard chrome (`0xFFD1D5DB` and 3 more) in `lib/ui/search/keyboard.dart`,
  light-mode-only styling.
- Overlay scrim `0x22000000` in `goal_reached_overlay.dart`.
- Hardcoded white/black text colors in
  `lib/ui/home/panel_area/hebrew_greek_panel/text.dart` (~10 sites) — the
  scripture text renderer does not read the theme at all, so dark/light
  parity is by luck.
- Opacity variants created inline everywhere via
  `colorScheme.primary.withValues(alpha: 0.7)` / `0.16` / `0.9` — alphas are
  tokens-in-waiting but are currently per-callsite decisions.

### Typography — defined in two competing systems

- **System 1: `TextTheme`.** `fontFamily: 'sbl'` global, `bodyLarge: 18`,
  `titleLarge: 22 bold`, app-bar title `20 bold`, plus full button text
  styles. 38 reads of `textTheme.*` — this system works.
- **System 2: inline sizes.** ~20 distinct hardcoded `fontSize:` values
  scattered across 20+ files (`9, 10, 10.5, 11, 12, 13.5, 14, 15, 16, 18,
  20, 22, 24, 25, 30, 34`). No named scale; every author invents a size.
- **System 3: user-adjustable scale.** `UserSettings` holds `baseFontSize`
  plus per-surface multipliers (`hebrewFontScale`, `greekFontScale`,
  `bibleFontScale`, `wordDetailsFontScale`), rendered by passing computed
  sizes down through widget params (`fontSize: 20.0` defaults on
  `VerseListItem`) or multiplying inside build methods (`WordDetailsDialog`'s
  `baseFontSize * 0.8 * scale`). This is the app's most distinctive
  typographic requirement — scripture text size is a user setting — and it
  has no token representation.

### Spacing — absent as tokens, de facto 4px grid

`SizedBox`/`EdgeInsets` values cluster on 4/8/12/16/24/32 but nothing declares
a scale. Recurring literal paddings: card `EdgeInsets.all(16)`, settings
`contentPadding left:32 right:16`, sheet padding `fromLTRB(12, 8, 12, 0)`.

### Radius — absent as tokens, 14 distinct values

`circular(2…999)` with heavy duplication at 8 (×15), 12 (×11), 14 (×6),
24 (×3). A shape scale is crying out to exist; the values already cluster.

### Elevation/shadow — incidental

Messenger card `elevation: 6`, app bars use `scrolledUnderElevation: 2`.
Nothing else is deliberate.

### Motion — absent

Durations are per-callsite: 100, 200 (×4), 220, 250 (×3), 300 (×3), 500 (×2),
1000, 1500 ms. Curves (`easeOutCubic`/`easeInCubic` in `MessengerHost`) are
chosen ad hoc. No duration/curve tiers.

### Iconography — defined (inherited)

Material Icons throughout, with one custom icon: `SparkleIcon`
(`lib/ui/common/sparkle_icon.dart`) — the "AI-generated" mark, drawn as a
path, reused by `WordPopup` and `WordDetailsDialog`. The messenger's
severity→icon mapping is a good semantic set.

### Directionality — defined

RTL is handled seriously for a scripture app: `TextDirection` is a parameter
on `VerseListItem`, `WordPopup`, `ParallelVerseData`; a dedicated
`resource_language_text_direction.dart` helper maps language → direction.

## Atoms

Defined (reusable single-purpose widgets that already exist):

- `ProgressCircle` (`reading_plan/ui/progress_circle.dart`) — themed, fully
  parameterized (size/stroke/fontSize). Best-behaved component in the repo.
- `NumberStepper` (`reading_plan/ui/number_stepper.dart`) — input control
  with min/max/step/decimal.
- `SparkleIconWidget` (`ui/common/sparkle_icon.dart`).
- `FloatingReturnPill` (`ui/home/word_details_dialog/floating_return_pill.dart`).
- `SwipeableSelectorButton`, `NumberSelector`, `ReferenceInputField`,
  `BookSelector` (`ui/home/appbar/reference_chooser/`) — a whole family of
  reference-selection atoms.
- `NumericKeypad` / `KeypadLayer` (`ui/home/keypad/`) — Hebrew/Greek on-screen
  keyboard.
- `HebrewGreekKeyboard` (`ui/search/keyboard.dart`) — larger but atom-family.

Extractable (recurring inline patterns):

- **Verse badge** — the translation badge inside `VerseListItem`
  (`borderRadius 4, fontSize 10.5, surfaceContainerHighest`): a pill/badge
  atom used at least twice conceptually (badges, severity chips).
- **Section header / card title** — repeated bold-title-plus-chevron rows
  (`ReadingPlanCard._planTitle`, settings `ExpansionTile` titles).
- **Severity icon set** — `_icon(MessageSeverity)` in `messenger_host.dart`;
  should be promoted next to the severity tokens it belongs with.

## Molecules

Defined:

- `VerseListItem` (`ui/common/`) — reference row + tappable rich-text verse +
  parallel translations with badges. Reused by `SearchPage` and
  `SimilarVersesPage`. Note: it calls `getIt<GlossService>()` internally, so
  it is not yet a pure presentational molecule.
- `_MessageCard` inside `MessengerHost` — icon + live-region text + dismiss,
  fully severity-tokenized (once severity colors are promoted).
- `WordPopup` (`ui/common/`) — anchored floating gloss popup with AI sparkle
  and directionality.
- `ReadingPlanCard` (`reading_plan/ui/`) — a well-composed molecule:
  `ProgressCircle` + title + two progress rows + bookmark ribbon + resume
  button.
- `DownloadProgressDialog` (`ui/common/`) — progress + cancel + auto-close.
- `ReadingSessionHud`, `ReadingSessionTimerView` (`reading_plan/ui/`).
- `GuideBubble` (`ui/home/common/`) — onboarding coach mark with cutout.
- `CalendarView` (`reading_plan/ui/calendar_view.dart`).

Extractable:

- **Settings row / chooser row** — the pattern "ListTile showing current
  value → tap → dialog with `SegmentedButton`/list/slider" is implemented six
  times across `section_theme`, `section_language`, `section_gloss_language`,
  `section_bible`, `section_verse_layout`, `section_font_size`. A
  `SelectionRow` molecule with a couple of variants would delete hundreds of
  lines.
- **Confirm dialog** — `DeleteReadingPlanConfirmDialog` and
  `DiscardBookListChangesDialog` are the same molecule (title/body/cancel/
  destructive-action) instantiated twice.
- **Font-size dialog** — `_showFontSizeDialog` (preview + slider) inside
  `section_font_size.dart`; belongs beside `NumberStepper` as a shared input
  molecule given font size is a first-class user setting.
- **Bottom-sheet chrome** — `ReadingSheet.navigateTo` and
  `ParallelTranslationsSheet` both hand-roll `showModalBottomSheet` with the
  same rounded-top shape, `isScrollControlled`, safe-area handling, and
  view-model construction/disposal boilerplate. One sheet scaffold molecule
  covers both.
- **Overlay/celebration family** — `GoalReachedOverlay`, `ConfettiOverlay`,
  `BookCompletedOverlay` share a shape (event-driven full-screen overlay with
  dismiss and celebratory content); only confetti is genuinely bespoke.
- **Card** — `ReadingPlanCard`'s outer container (surfaceContainerLow, radius
  24, padding 16) is the app's card pattern; also appears (radius 14) in
  `resource_section.dart` rows.

## Organisms

Defined:

- `HomeScreen` composition: `HomeAppBar` + `AppDrawer` + `ReferenceChooser`
  + `BiblePanelArea` (which composes `HebrewGreekPanel`, `BiblePanel`,
  `VerseSyncLayout`, `InfiniteScrollView`) + `MessengerHost` +
  `WordStudyOverlayLayer` + reading-session overlays + audio player.
- `WordDetailsDialog` + `SimilarVersesPage` + `ParallelTranslationsSheet` —
  the word-study flow.
- `SearchPage` + `HebrewGreekKeyboard`.
- `DownloadManagerPage` + `ResourceSection` (tree list with download/update
  state).
- Reading-plan cluster: `ReadingPlanPanel`, `ReadingPlanDetailPanel`,
  `EditReadingPlanPanel`, `EditBookListPanel`, `DayActivityLogPanel`.
- `ResourceDownloadPromptDialog` (`ui/common/resource_ui_helper.dart`).

Extractable / unifying:

- **App bar family** — `HomeAppBar`, `ReadingPlanAppBar` (a flat,
  transparent, secondary app bar — generalizable beyond reading plans), and
  default `AppBar`s on `SettingsPage`/`DownloadManagerPage` are three
  different answers to the same question.
- **Panel/manager scaffolding** — every panel follows "manager/ChangeNotifier
  + widget" (a view-model pattern, not a design-system concern, but it
  constrains how organisms get their data, so it belongs in the plan's
  component-API conventions).

## Templates

- **Scaffold page** — `SettingsPage`, `DownloadManagerPage`, `AboutPage`,
  `SearchPage`, `BackupRestorePage`, `SimilarVersesPage` all use plain
  `Scaffold + AppBar + body`. Consistent by accident (Material defaults), not
  by convention.
- **Modal bottom sheet** — `ReadingSheet`, `ParallelTranslationsSheet`.
- **Full-screen dialog "page"** — `WordDetailsDialog`; the word-study flow
  treats a dialog as a navigable page, with `FloatingReturnPill` as its
  return affordance.
- **Overlay layer stack** — `MessengerHost` (top), `WordStudyOverlayLayer`,
  `KeypadLayer`, guide/celebration overlays. The home screen's `Stack` layout
  is the de facto overlay template.

## Pages (views in use)

Home (reader), Search, Word study (dialog flow), Similar verses /
occurrences, Reading plan sheet + panels, Reading session (HUD, timer,
celebrations), Settings, Download manager, Backup/restore, About + changelog
dialog.

## Infrastructure that a design system needs (already present)

- Theming infra: `darkTheme`/`lightTheme` + `AppState.themeMode` — light/dark
  switching works end to end.
- l10n: complete, 5 languages (`lib/l10n/`) — components are already written
  against `AppLocalizations`, which is the strongest existing discipline in
  the UI layer.
- Component hosts: `MessengerHost`, `StreamDialogHost`, `ZoomWrapper` — the
  "slot + host" patterns a component library needs for messaging, dialogs,
  and gesture wrapping.
- Test setup: 50 test files, real-services-plus-fakes pattern; **no golden
  tests or component gallery yet** — the biggest gap for *enforcing* any
  design system.

## Cross-cutting observations (gaps, not inventory)

- The token layer is the missing foundation: everything above composes
  correctly, but on raw literals. ~62 off-theme colors, ~20 font sizes, 14
  radii, ad hoc durations.
- There is no shared-UI slice. `lib/ui/common/` is the embryo of one, but
  components live wherever they were first needed (`reading_plan/ui/` has its
  own app bar and progress circle) and `ARCHITECTURE.md`'s vertical-slices
  rules don't yet say where a *design system* lives or how a component gets
  promoted into it.
- Some components are not extraction-ready because they own logic:
  `VerseListItem` resolves `GlossService` itself; all six settings sections
  use `getIt` + `setState` rather than view models. Atoms/molecules must be
  made presentational before they can be shared cleanly (this is a
  pre-existing architecture-conformance issue the design system work will
  surface).
- Dark/light parity is unverified in the scripture text renderer and the
  search keyboard.
