# Download Manager UI

## Overview
Provides the user interface for browsing, downloading, updating, and removing modular study resources (glosses, Bibles, and audio packs) organized by language and category.

## Interface
- `download_manager_page.dart:DownloadManagerPage`: Main management screen providing language filtering, catalogue refresh, and categorized resource sections.
- `resource_section.dart:ResourceSection`: Stateful expandable section grouping resources by `ResourceType` and tracking update indicators.
- `resource_section.dart:ResourceTreeNode`: Recursive hierarchical model representing nested resource bundles and calculating descendant update counts.

## Invariants
- If the selected download language is no longer present in available languages, `UserSettings.downloadLang` resets to null.
- Download and delete operations are locked while `_busy` is true to prevent duplicate tasks.
- Resource tree builds hierarchically based on slash-delimited identifier paths.

## Side Effects
- Mutates user setting `downloadLang` via `UserSettings.setDownloadLang`.
- Subscribes to and unsubscribes from `ResourceService` resource change notifications.
- Executes network catalog sync via `ResourceService.refresh`.
- Initiates network downloads and file system deletions via `ResourceService.downloadResource` and `ResourceService.deleteResource`.
- Opens `DownloadProgressDialog` and displays error `SnackBar` notifications.

## Verification
- Run: `flutter test`
