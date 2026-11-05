# Panel Area Common UI

## Overview
Provides common components and overlays used across reading panels, including infinite scrolling slivers, session goal progress bars, confetti celebration animations, book completion modals, and monthly reading plan calendar views.

## Interface
- `infinite_scroll_view.dart:ChapterBuilder`: Function signature creating chapter widgets for dynamically loaded book and chapter identifiers.
- `infinite_scroll_view.dart:VerseScrollable`: Mixin contract enabling chapter widgets to report pixel offsets for verse numbers and resolve verse numbers from vertical offsets.
- `infinite_scroll_view.dart:InfiniteScrollView`: Multi-chapter viewport dynamically prepending and appending slivers as the user scrolls, synchronizing offset positions with external controllers.
- `infinite_scroll_view.dart:InfiniteScrollViewState`: State class managing chapter caching, sliver layout keys, and bidirectional scroll syncing.
- `reading_session_overlay.dart:ReadingSessionOverlay`: Horizontal banner displaying active daily reading goal progress (verses read or minutes spent).
- `goal_reached_overlay.dart:GoalReachedOverlay`: Celebration overlay displaying completion messaging, confetti animation, and continue/finish session prompts.
- `book_completed_overlay.dart:BookCompletedOverlay`: Modal dialog congratulating the reader upon finishing a biblical book and providing a button to advance to the next book in the plan.
- `confetti_view.dart:ConfettiOverlay`: Full-screen particle physics animation simulating celebratory confetti bursts.
- `calendar_view.dart:CalendarView`: Month grid widget highlighting days where reading sessions or goals were achieved.

## Invariants
- `InfiniteScrollView` automatically requests previous or next chapter slivers when scroll position is within 400 pixels of viewport boundaries.
- Programmatic verse scrolls suppress geometric scroll sync reporting until the target position is reached.
- `CalendarView` bounds grid day indices to not exceed the provided data list capacity.

## Side Effects
- Reads and updates scroll position and verse jump streams via `ScrollSyncController`.
- Invokes session completion and reading mode mutations on `ReadingSessionManager`.
- Executes continuous particle canvas rendering and timer-based prompt delays.

## Verification
- Run: `flutter test`
