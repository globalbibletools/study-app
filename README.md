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

## Licenses

The source code for this app is in the [public domain (CC0)](https://creativecommons.org/public-domain/cc0/) as stated in the [LICENSE](https://github.com/globalbibletools/study-app/blob/main/LICENSE) file.

However, the app also makes use of other resources that are not in the public domain:

- SBL Hebrew/Greek font. Non-commercial use allowed. See the license in the [assets/fonts](https://github.com/globalbibletools/study-app/tree/main/assets/fonts) folder.
- [UBS Dictionary of Biblical Hebrew/Greek](https://github.com/ubsicap/ubs-open-license/tree/main/dictionaries): [Creative Commons Attribution-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-sa/4.0/).