# Development

Practical, day-to-day details for working in this repo.

## Environment setup

The Nix flake provides everything: `nix develop` gives you the Flutter, the
Android SDK (including the emulator and system images), and other build tools
for android and ios.

Alternatively, the Flutter version is pinned with FVM in `.fvmrc`: run
`fvm install` once, then use `fvm flutter ...` in place of `flutter ...`.

Docker is needed for [ministack](#ministack-asset-server) work.

## Everyday commands

- Analyze: `flutter analyze`
- Format: `dart format .`
- Format (check only): `dart format --output=none --set-exit-if-changed .`
- Test (all): `flutter test`
- Test (one file): `flutter test test/path/to_test.dart`
- Test (filter): `flutter test --name "some pattern"`

Lints and the 80-column format width are configured in
`analysis_options.yaml`.

Tests run on the host, not on a device: database tests use `sqflite_common_ffi`.
The only code generation in the repo is localizations (`flutter gen-l10n`,
run automatically during builds).

## Verification before considering work done

```
flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test
```

## Emulators

The `emulator` command comes from the Android SDK in the Nix shell.

```
emulator -list-avds          # list AVDs
emulator -avd <name>         # start one (blocks; run in a separate terminal)
adb devices                  # show running devices and their ids
adb -s emulator-5554 emu kill   # stop a specific emulator
```

Useful flags: `-no-snapshot` (cold boot), `-wipe-data` (reset the AVD),
`-no-window -gpu swiftshader_indirect` (headless).

## Running the app

```
flutter devices          # list targets
flutter run -d <id>      # run on one target (e.g. emulator-5554, macos)
flutter run -d all       # run on every connected target
```

While `flutter run` is in the foreground: `r` hot reloads, `R` hot restarts,
`q` quits. `flutter attach` connects to an already-running debug build.

### Signaling a running `flutter run`

The tool installs signal handlers, which is how to reload/restart when you do
not own the terminal it is running in (e.g. a background process or an agent
session):

- SIGUSR1: hot reload
- SIGUSR2: hot restart
- SIGINT/TERM: clean quit

```
flutter run -d emulator-5554 --pid-file /tmp/flutter.pid &
kill -USR1 $(cat /tmp/flutter.pid)   # hot reload
kill -USR2 $(cat /tmp/flutter.pid)   # hot restart
kill -USR1 ... # after edits: reload again
```

## ministack (asset server)

Ministack is a local S3-compatible server used to test asset downloads
(bibles, glosses, audio) without hitting the production asset server. This
is useful when you need to change what will be available on the file server.

```
docker compose up -d
curl http://localhost:4566/_ministack/health
```

Assets placed in `ministack/assets/{audio,bibles,glosses}` are synced into an
`assets` bucket with anonymous public reads. Seeding happens at container
startup, so after adding files, `docker compose restart` to re-sync. State
persists in named volumes; `docker compose down -v` resets it.

The app must be pointed at ministack with a `--dart-define`, or it will talk
to production:

- Android emulator: `--dart-define=ASSETS_BASE_URL=http://10.0.2.2:4566/assets`
  (`10.0.2.2` is the host loopback seen from inside the emulator)
- iOS simulator: `--dart-define=ASSETS_BASE_URL=http://localhost:4566/assets`
- Physical device: `--dart-define=ASSETS_BASE_URL=http://<your LAN IP>:4566/assets`

```
flutter run -d emulator-5554 --dart-define=ASSETS_BASE_URL=http://10.0.2.2:4566/assets
```

## Driving the Android emulator

The Android package is `com.globalbibletools.gbt`.

```
adb shell input tap 540 1200            # tap at coordinates
adb shell input swipe 540 1500 540 500  # swipe/scroll
adb shell input keyevent 4              # back
adb shell input text "hello"

adb shell pm clear com.globalbibletools.gbt   # wipe app data (test fresh installs/migrations)
adb shell am force-stop com.globalbibletools.gbt
adb shell am start -n com.globalbibletools.gbt/com.ryanheise.audioservice.AudioServiceActivity

adb shell am start -a android.intent.action.VIEW -d "https://globalbibletools.com/..."
```

To find coordinates for taps, dump the view hierarchy (`adb shell
uiautomator dump`, then pull `/sdcard/window_dump.xml`) or take a screenshot
(`adb exec-out screencap -p > shot.png`). App logs surface in
`adb logcat -s flutter`.

## Inspecting app data from the emulator

Debug builds are debuggable, so `run-as` grants access to the app's private
storage, rooted at `/data/data/com.globalbibletools.gbt/`. Downloaded assets
live under `files/` (`files/bibles/`, `files/glosses/`, `files/audio/`);
SQLite databases under `databases/`.

```
adb shell run-as com.globalbibletools.gbt ls -R files
adb exec-out run-as com.globalbibletools.gbt cat files/bibles/hebrew_greek.db > hebrew_greek.db
adb exec-out run-as com.globalbibletools.gbt tar -cf - files | tar -xf -
```

`run-as` does not work on profile/release builds.
