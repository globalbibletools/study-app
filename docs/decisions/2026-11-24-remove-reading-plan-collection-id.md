# Remove the Persisted Reading Plan Collection Id

- Date: 2026-11-24
- Status: In Review
- Supersedes: None
- Superseded By: None

# Context

A reading plan stores an ordered list of books in `reading_plan_book`. It also
stored a `collection_id` on `reading_plan` that named a preset book set (Whole
Bible, Old Testament, New Testament, and so on). The id duplicated information
already present in the ordered list and could disagree with it: any code path
that changed the book list without also updating the id left the plan
describing a collection it did not contain.

The UI already treated a plan whose book list did not match a preset as
Custom. The persisted id therefore added no capability; it only added a second
source of truth to keep in sync.

# Decisions

The ordered `reading_plan_book` list is authoritative for which books a plan
covers. The plan's collection is derived by comparing that list directly
against the preset lists, falling back to Custom when none match.

- `BibleCollection` is a plain Dart enum with the preset book lists and a
  `custom` value whose list is empty. It has no numeric id, no display name,
  and no localization; widgets own the presentation labels.
- `collection_id` was removed from `reading_plan`, from the `ReadingPlan`
  model, and from the service and database save/update APIs.
- The `ReadingSessionDatabase` schema version moves from 7 to 8. The v8
  migration rebuilds `reading_plan` without the column because older Android
  SQLite builds do not support `ALTER TABLE ... DROP COLUMN`.
- Backup restore drops legacy `collection_id` keys from `reading_plan` rows.
  Old v1 and v2 backups remain restorable; the column is ignored rather than
  interpreted.

# Implementation Notes

- Version 8 uses a create-copy-drop table rebuild that preserves row ids,
  defaults, and foreign key relationships. Historical migrations 2 through 7
  are untouched so existing upgrade paths still run as they did.
- Backup format version 2 is unchanged. Only the restore path tolerates the
  extra legacy column, so a backup written before this change restores into
  the new schema.
- The edit view model derives `selectedCollection` from the current ordered
  book list and keeps the user's custom draft in memory while switching
  between presets and Custom.
- Collection names are localized in `EditReadingPlanPanel` with an exhaustive
  switch, keeping the model free of Flutter and l10n imports.

# Alternatives

- Keep `collection_id` and update it whenever the book list changes. Rejected:
  it preserves a denormalized field whose only consumer can derive the same
  value from the authoritative list.
- Use `ALTER TABLE reading_plan DROP COLUMN collection_id`. Rejected: it needs
  SQLite 3.35 or newer, while sqflite on Android uses the OS-bundled SQLite
  and the app supports older devices.
- Keep the id only in backup payloads and ignore it on restore. Rejected: the
  column would still exist in the live schema without a consumer, and every
  writer would have to fabricate a value.

# References

- [Four-Layer Architecture](2026-11-18-four-layer-architecture.md)
- [Vertical Slices](2026-11-19-vertical-slices.md)
- `docs/DOMAIN.md`, "Bible collection": the book list is the source of truth.
- `assets/schemas/reading_session_8.sql`
