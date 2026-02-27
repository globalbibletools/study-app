# Study App

A Hebrew and Greek reader for [Global Bible Tools](https://globalbibletools.com).

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

## Updating Audio Files & Timings

When you need to update an existing audio recording, follow these steps:

### 1. Prepare the New Audio File
- **Rename the file:** Append a version suffix. 
  - Example: `001.mp3` becomes `001_v2.mp3`.
  - If a `v2` already exists, name it `001_v3.mp3`.
- **Keep the old file:** **Do not delete** the old file (`001.mp3`) from the server. Older versions of the app still depend on it.

### 2. Update the Timings CSV
- **New Timings:** Update the timing values to match the new audio file. (Use Isochron)
- **Update Version:** Set the `version` column to the new number (e.g., `2`) for **every verse** in that chapter for that specific `recording_id`. (TODO: create a way to do this.)

### 3. Deploy
- **Upload:** Upload the new MP3 to the same directory on the server (e.g., `/audio/RDB/Gen/001_v2.mp3`).
- **Regenerate DB:** Run the database population script to create the new `audio_timings.db`. Update the db version number.
- **App Update:** Update the db in the app assets. Update the db version number.

## Licenses

The source code for this app is in the [public domain (CC0)](https://creativecommons.org/public-domain/cc0/) as stated in the [LICENSE](https://github.com/globalbibletools/study-app/blob/main/LICENSE) file.

However, the app also makes use of other resources that are not in the public domain:

- SBL Hebrew/Greek font. Non-commercial use allowed. See the license in the [assets/fonts](https://github.com/globalbibletools/study-app/tree/main/assets/fonts) folder.
- [UBS Dictionary of Biblical Hebrew/Greek](https://github.com/ubsicap/ubs-open-license/tree/main/dictionaries): [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).