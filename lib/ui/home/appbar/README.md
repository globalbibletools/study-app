# Home App Bar

## Overview
Houses top-level navigation components for the main study screen, including Scripture reference navigation, reading mode toggles, audio playback triggers, panel split controls, navigation drawer routing, and log export utilities.

## Interface
- `appbar.dart:HomeAppBar`: Application bar implementing `PreferredSizeWidget`, hosting reference selection, session badges, and study action buttons.
- `drawer.dart:AppDrawer`: Primary navigation drawer providing access to settings, search, downloads, about page, database backup, and zip log exporting.
- `reading_session_timer_view.dart:ReadingSessionTimerView`: Floating session duration badge formatting elapsed reading seconds in tabular layout.
- [Reference Chooser](./reference_chooser/README.md): Interactive selectors for Bible book, chapter, and verse navigation.

## Invariants
- `HomeAppBar.preferredSize` maintains fixed toolbar height equal to `kToolbarHeight`.
- Log export is aborted if `LogExporter` yields empty byte content.

## Side Effects
- Pushes navigation routes for Settings, Search, Downloads, About, and Backup screens.
- Flushes logs via `AppLogger.flush` and exports zip archives to storage using `FilePicker.saveFile`.
- Listens to `ResourceService.outdatedResourceCounts` to render update alert badges.
- Toggles goal progress visibility via `ReadingSessionService.toggleDisplayGoalProgress`.

## Verification
- Run: `flutter test`
