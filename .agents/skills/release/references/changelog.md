# Changelog

The in-app changelog is the user-facing record of what changed. Its canonical
source is the localized JSON under `assets/l10n/`, as decided in
[the in-app changelog decision](../../../../docs/decisions/2026-11-26-changelog.md).
`CHANGELOG.md` is historical and is not updated by the release workflow.

## When notes are needed

Notes are optional. A public release with no user-facing changes is prepared
with `--no-changelog` and only updates `pubspec.yaml`.

A beta release never adds a changelog entry. Beta notes, if any, belong in the
PR and GitHub release; the in-app entry is written when the public release is
prepared.

When a release does have user-facing changes:

1. Draft the notes in English.
2. Suggest `major` or `minor` and wait for a human to confirm both the text
   and the type. For a `major` entry, also draft its summary and get it
   confirmed.
3. Translate the approved summary and notes into every app locale.
4. Supply all locales to `prepare` in one input file.
5. The human reviews the translations in the release PR.

### Type

- `major` — an unseen entry triggers the what's-new dialog. Every `major`
  entry also has a short translated `summary`, which is the dialog body and
  the lead paragraph on the changelog page.
- `minor` — the entry appears only in the changelog list and has no summary.

Use `major` for a release users should be told about, not for every patch.

## Stored entry format

Every `assets/l10n/changelog_<locale>.json` file is a JSON array, oldest
first. A `major` entry has exactly this shape:

```json
{
  "version": "26.11.0",
  "date": "2026-11-28",
  "type": "major",
  "summary": "This release makes downloaded resources easier to manage.",
  "changes": [
    "Download and manage Bibles, glosses, and audio.",
    "New settings for the Bible translation and gloss language."
  ]
}
```

A `minor` entry has the same shape without the `summary` key:

```json
{
  "version": "26.10.0",
  "date": "2026-10-29",
  "type": "minor",
  "changes": [
    "Logs export for solving issues in the app."
  ]
}
```

Rules:

- `version` is a public release (`YY.MM.C`). It never has a `-betaN` suffix
  and never has build metadata. A beta tag does not get its own entry; the
  eventual public release carries the notes.
- `date` is an ISO calendar date, `YYYY-MM-DD`, and is the release date.
- `type` is `major` or `minor`.
- `summary` is required on `major` entries and is a non-empty string. It must
  be absent from `minor` entries.
- `changes` is a non-empty array of non-empty strings.
- Entries are unique and strictly increase in version order. New entries are
  appended at the end. Existing entries are never edited, reordered, or
  removed.

## Prepare input format

The file passed to `prepare --changelog` is JSON with exactly the keys `type`,
`changes`, and, for major entries, `summary`. It does not contain a version or
date; those come from `--version` and `--date` so the tool stays the source of
truth.

```json
{
  "type": "major",
  "summary": {
    "ar": "تسهّل هذه النسخة إدارة الموارد التي تم تنزيلها.",
    "en": "This release makes downloaded resources easier to manage.",
    "es": "Esta versión facilita la gestión de los recursos descargados.",
    "fr": "Cette version facilite la gestion des ressources téléchargées.",
    "pt": "Esta versão facilita o gerenciamento dos recursos baixados."
  },
  "changes": {
    "ar": [
      "أصبح من الممكن تصدير السجلات لحل المشكلات.",
      "تم إصلاح تشغيل الصوت عند تغيير الإصحاح أو مصدر الصوت."
    ],
    "en": [
      "Logs can now be exported for troubleshooting.",
      "Fixed audio playback when changing chapters or audio sources."
    ],
    "es": [
      "Ahora se pueden exportar los registros para solucionar problemas.",
      "Se corrigió la reproducción de audio al cambiar de capítulo o de fuente de audio."
    ],
    "fr": [
      "Les journaux peuvent désormais être exportés pour le dépannage.",
      "Correction de la lecture audio lors du changement de chapitre ou de source audio."
    ],
    "pt": [
      "Agora é possível exportar os registros para solução de problemas.",
      "Corrigida a reprodução de áudio ao mudar de capítulo ou de fonte de áudio."
    ]
  }
}
```

For a `minor` entry, omit the `summary` key entirely.

- `type` must be `major` or `minor`.
- `changes` must contain exactly the app locales discovered from
  `lib/l10n/app_<locale>.arb`. Missing locales, extra locales, and unknown
  top-level keys are rejected.
- Every locale's value is a non-empty array of non-empty strings.
- `summary` is required for `major` and must be absent for `minor`. When
  present it must contain exactly the same locales as `changes`, each with a
  non-empty translated string.

The same `changes` count is not required across locales; the note text is
translated per locale. The version, type, and date are shared.

## Locale consistency

The app's locale list comes from `lib/l10n/app_<locale>.arb`. Every app
locale must have `assets/l10n/changelog_<locale>.json`, and a changelog file
without a matching app locale is an error. Every locale file must have the
same number of entries with the same version, type, and date at each index.
Translated `summary` and `changes` text differ. The app falls back to English
per file at runtime when it is missing a locale, but the release tool still
requires every current locale so the sequences cannot drift.

## Append-only behavior

`prepare` appends one entry per locale and never rewrites history. If the
same entry (version, date, type, that locale's summary, and that locale's
changes) already exists at the end of a file, it is treated as already applied
and left untouched. If an entry for the version exists with different content,
the tool refuses rather than editing it. A version older than the last entry
is rejected.

The tool validates all locales and the complete input before writing any
file, so a failed preparation leaves `pubspec.yaml` and the changelog files
unchanged.
