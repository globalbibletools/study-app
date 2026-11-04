# Reading Plan UI

## Overview
Provides the full modal sheet interface and navigation flow for managing Bible reading plans, including plan creation, book selection, drag-and-drop book reordering, daily goal configuration (verses or minutes), and detailed progress auditing per session.

## Interface
- `reading_sheet.dart:ReadingSheet`: Root modal container wrapping reading plan navigation in an isolated nested navigator.
- `reading_plan_panel.dart:ReadingPlanPanel`: Overview panel listing all reading plans with progress bars, completion percentages, and session resumption triggers.
- `reading_plan_panel.dart:ReadingPlanPanelState`: State class managing edit mode toggles and plan list rendering.
- `reading_plan_panel_manager.dart:ReadingPlanPanelManager`: ViewModel aggregating chapter/verse totals, books read, and latest book progress across plans.
- `reading_plan_panel_manager.dart:MainTab`, `ProgressTab`, `BookProgressTab`, `GoalsTab`: Tab navigation enums for reading plan progress screens.
- `add_reading_plan_panel.dart:AddReadingPlanPanel`: Form panel for naming a plan, choosing a Bible collection, selecting books, and configuring daily reading goals.
- `add_reading_plan_panel_manager.dart:AddReadingPlanPanelManager`: Persistence manager executing inserts and updates for plans and ordered book lists.
- `reading_plan_detail_panel.dart:ReadingPlanDetailPanel`: Detailed view of a specific plan showing circular progress, daily goal completion, calendar history, and reorderable book lists.
- `reading_plan_detail_panel.dart:ReadingPlanDetailPanelState`: State class managing local book reordering and estimated completion calculations.
- `reading_plan_detail_panel_manager.dart:ReadingPlanDetailPanelManager`: ViewModel syncing bookmark state, monthly progress data, and updated book orders.
- `detailed_progress_panel.dart:DetailedProgressPanel`: Modal breakdown displaying individual timestamps, duration in minutes, and verse ranges read during a given day's sessions.
- `detailed_progress_panel_manager.dart:DetailedProgressPanelManager`: ViewModel querying day session details from `ReadingSessionManager`.

## Invariants
- Creating or updating a reading plan requires a non-empty plan name and at least one chosen book.
- Custom book order positions persist strictly as 1-indexed contiguous ordinals (`ord = 1..N`).
- Daily goal target numbers must be greater than zero.

## Side Effects
- Mutates reading plans, book mappings, and bookmark states in `ReadingSessionDatabase`.
- Starts reading sessions and queries history in `ReadingSessionManager`.
- Manages nested route transitions (`Navigator.push`, `showModalBottomSheet`, `showDialog`).

## Verification
- Run: `flutter test`
