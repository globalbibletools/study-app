# Reading Plan UI

## Overview
Provides the full modal sheet interface and navigation flow for managing Bible reading plans, including plan creation, book selection, drag-and-drop book reordering, daily goal configuration (verses or minutes), and detailed progress auditing per session. Panel ViewModels use `ReadingPlanService` for plan CRUD and on-demand progress/statistics queries, and `ReadingSessionManager` only for active-session state.

## Interface
- `reading_sheet.dart:ReadingSheet`: Root modal container wrapping reading plan navigation in an isolated nested navigator, constrained to 85% of screen height with top rounded corners.
- `reading_plan_panel.dart:ReadingPlanPanel`: Overview panel listing all reading plans with progress bars, completion percentages, plan deletion, and session resumption triggers.
- `reading_plan_panel.dart:confirmDeleteReadingPlan`: Shared modal dialog helper confirming reading plan deletion.
- `reading_plan_panel.dart:ReadingPlanPanelState`: State class managing edit mode toggles and plan list rendering.
- `reading_plan_panel_manager.dart:ReadingPlanPanelManager`: ViewModel aggregating chapter/verse totals, books read, and latest book progress across plans via `ReadingPlanService`, and starting sessions via `ReadingSessionManager`.
- `add_reading_plan_panel.dart:AddReadingPlanPanel`: Form panel for naming a plan, choosing a Bible collection, selecting books, configuring daily reading goals, and deleting plans.
- `add_reading_plan_panel_manager.dart:AddReadingPlanPanelManager`: ViewModel delegating plan creation, updates, and deletion to `ReadingPlanService`.
- `reading_plan_detail_panel.dart:ReadingPlanDetailPanel`: Detailed view of a specific plan showing circular progress, daily goal completion, calendar history, and reorderable book lists.
- `reading_plan_detail_panel.dart:ReadingPlanDetailPanelState`: State class managing local book reordering and estimated completion calculations.
- `reading_plan_detail_panel_manager.dart:ReadingPlanDetailPanelManager`: ViewModel using `ReadingPlanService` for progress data, bookmark, and book-order mutations, and `ReadingSessionManager` for session start.
- `detailed_progress_panel.dart:DetailedProgressPanel`: Modal breakdown displaying individual timestamps, duration in minutes, and verse ranges read during a given day's sessions.
- `detailed_progress_panel_manager.dart:DetailedProgressPanelManager`: ViewModel querying day session details from `ReadingPlanService`.

## Invariants
- `ReadingSheet` is constrained to 85% screen height and uses safe area so top drag handles do not conflict with the Android status bar.
- Creating or updating a reading plan requires a non-empty plan name and at least one chosen book.
- Custom book order positions persist strictly as 1-indexed contiguous ordinals (`ord = 1..N`) and are preserved on plan edits; reordering refreshes the detail manager's latest-book notifier.
- All panel backgrounds, cards, buttons, text styles, and calendar cells dynamically adapt to both light and dark theme brightnesses using Material 3 color schemes.
- Daily goal target numbers must be greater than zero.
- Panel ViewModels use `ReadingPlanService` for CRUD mutations and progress/statistics queries, while `ReadingSessionManager` is reserved for active-session concerns.

## Side Effects
- Mutates reading plans, book mappings, and bookmark states through `ReadingPlanService`.
- Starts active reading sessions through `ReadingSessionManager`.
- Manages nested route transitions (`Navigator.push`, `showModalBottomSheet`, `showDialog`).

## Verification
- Run: `flutter test`
