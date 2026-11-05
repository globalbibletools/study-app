# lib

## Overview
Root application source package for the Global Bible Tools study application. Coordinates application bootstrap, dependency container initialization, theme and locale state management, and wires top-level presentation and service subsystems.

## Interface
- `app_state.dart:AppState`
- `main.dart:main()`
- `main.dart:GbtStudyApp`
- `theme.dart:lightTheme`
- `theme.dart:darkTheme`
- Subdirectories & Subsystems:
  - [Common Domain Models & Navigation](./common/README.md): Biblical coordinate representations, canonical book ordering, and navigation math.
  - [Localization & Multilingual Resources](./l10n/README.md): Generated localization delegates and multilingual Scripture book name resolvers.
  - [Reactive Utilities](./rxutils/README.md): Stream combination utilities for multi-source reactive coordination.
  - [Services & Storage](./services/README.md): Data access layers, SQLite database controllers, HTTP download handlers, and logging infrastructure.
  - [User Interface](./ui/README.md): Reader panels, on-screen keypad, reference chooser, reading plan sheets, and settings views.

## Invariants
- `main()` must execute `WidgetsFlutterBinding.ensureInitialized()` and `setupServiceLocator()` before resolving dependencies via `getIt`.
- `AppState` synchronizes runtime theme and locale preferences with `UserSettings` in `SharedPreferences`.
- Theme definitions require `sbl` typography font family.

## Side Effects
- Initializes SQLite databases (`HebrewGreekDatabase`, `LexiconsDatabase`, `ReadingSessionDatabase`).
- Spawns background audio service via `JustAudioBackground.init`.
- Initiates asynchronous catalog sync via `ResourceService.refresh()`.
- Renders root Flutter widget tree via `runApp(const GbtStudyApp())`.

## Verification
- Run: `flutter test`
