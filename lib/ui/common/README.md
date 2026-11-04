# Common UI

## Overview
Provides reusable widgets, helpers, and dialogs shared across the UI layer, including Bible translation selectors, download progress monitors, resource verification helpers, vector iconography, and verse list items.

## Interface
- `bible_chooser.dart:BibleOption`: Model class representing a selectable Bible translation option.
- `bible_chooser.dart:chooseBible`: Prompts the user with a dialog to select a Bible translation, updates user settings, and verifies/downloads the selected resource with automatic rollback on failure.
- `download_progress_dialog.dart:DownloadProgressDialog`: Modal progress dialog displaying percentage completion and cancellation handling for async background tasks.
- `resource_language_text_direction.dart:ResourceLanguageTextDirectionX`: Extension mapping `ResourceLanguageTextDirection` enum to Flutter `TextDirection`.
- `resource_ui_helper.dart:ResourceUIHelper`: Utility verifying resource availability and presenting download prompts/progress dialogs, deduplicating concurrent requests.
- `sparkle_icon.dart:SparkleIcon`: Custom vector path generator and canvas painter for celebration sparkle iconography.
- `sparkle_icon.dart:SparkleIconWidget`: Stateless widget wrapping `SparkleIcon` for display in Flutter widget trees.
- `verse_list_item.dart:VerseListItem`: Stateful widget rendering an asynchronous verse snippet with automatic keep-alive caching and bidirectional text support.

## Invariants
- `chooseBible` reverts to `previousBibleId` if the chosen translation fails verification or download.
- Identical resource check requests (`resourceType:id`) in `ResourceUIHelper.ensureResource` reuse existing pending futures.
- `VerseListItem` retains scroll state and prevents rebuilding via `AutomaticKeepAliveClientMixin`.

## Side Effects
- Mutates user configuration via `UserSettings.setCurrentBible`.
- Queries and downloads resources through `ResourceService`.
- Opens Flutter modals (`SimpleDialog`, `AlertDialog`, `DownloadProgressDialog`) and pushes error `SnackBar`s to `ScaffoldMessenger`.

## Verification
- Run: `flutter test`
