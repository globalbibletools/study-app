# Study App Blueprint

A Hebrew and Greek reader for [Global Bible Tools](https://globalbibletools.com).

## System Overview
The Global Bible Tools Study App is an offline-capable, cross-platform Flutter application and dataset pipeline for studying biblical Hebrew and Greek texts. The repository contains the primary Flutter client (`lib`), platform host runners (`android`, `ios`, `macos`, `linux`, `windows`), a dedicated database compiler toolchain (`database_builder`), schema definitions (`assets/schemas`), and a local cloud testing harness (`ministack`).


## System Verification
- Run: `flutter test`

---

## Publishing tips

Android

```
flutter build appbundle
flutter build apk --split-per-abi
```

iOS

```
flutter build ipa
```

Open in Xcode:

```
build/ios/archive/Runner.xcarchive
```

## Licenses

The source code for this app is in the [public domain (CC0)](https://creativecommons.org/public-domain/cc0/) as stated in the [LICENSE](https://github.com/globalbibletools/study-app/blob/main/LICENSE) file.

However, the app also makes use of other resources that are not in the public domain:

- SBL Hebrew/Greek font. Non-commercial use allowed. See the license in the [assets/fonts](https://github.com/globalbibletools/study-app/tree/main/assets/fonts) folder.
- [UBS Dictionary of Biblical Hebrew/Greek](https://github.com/ubsicap/ubs-open-license/tree/main/dictionaries): [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).

## Local development

The Flutter version is pinned with [FVM](https://fvm.app) in `.fvmrc`. Install the SDK with `fvm install`, then run Flutter commands through `fvm flutter`. If you use the Nix flake, Flutter is already provided, so FVM is not needed.

Run `docker compose up` to start ministack to be able to test asset downloads.
Assets stored in `ministack/assets` are available for the app to fetch.
