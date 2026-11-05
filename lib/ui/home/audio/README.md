# Audio Player

## Overview
Provides audio playback controls and state management for narrated Hebrew/Greek and Scripture audio, supporting synchronized verse tracking, repeat loops (none, chapter, verse), speed adjustment, and speaker selection.

## Interface
- `audio_player.dart:BottomAudioPlayer`: Bottom sheet player UI displaying reference titles, speaker dropdowns, seek bar, transport controls, and error states.
- `audio_player_view_model.dart:AudioPlaybackError`: Sealed class for audio playback failure types (`AudioFileMissingError`, `AudioUnknownError`).
- `audio_player_view_model.dart:AudioFileMissingError`: Error subtype emitted when audio file resources are unavailable for the active reference.
- `audio_player_view_model.dart:AudioUnknownError`: Fallback error subtype for general playback or decode exceptions.
- `audio_player_view_model.dart:AudioRepeatModeType`: Enum denoting repeat strategies (`none`, `chapter`, `verse`).
- `audio_player_view_model.dart:AudioPlaybackState`: Enum indicating playback states (`loading`, `playing`, `paused`).
- `audio_player_view_model.dart:AudioRepeatMode`: Configuration object capturing active repeat strategy and target verse.
- `audio_player_view_model.dart:SourceSetting`: Model pairing Old Testament and New Testament audio speaker IDs.
- `audio_player_view_model.dart:AudioPlayerViewModel`: Change notifier managing audio playback lifecycle, timing synchronization, chapter progression, and stream subscriptions.

## Invariants
- In `AudioRepeatModeType.verse`, audio position exceeding verse boundaries immediately seeks back to `timing.start`.
- Audio commands (`play`, `pause`, `seek`, `jumpTo`) are ignored when `isVisible` is false.
- Disposing `AudioPlayerViewModel` cancels position, player state, and error subscriptions, and unregisters resource change listeners.

## Side Effects
- Streams and controls audio media using `just_audio.AudioPlayer`.
- Sets system background playback metadata via `just_audio_background.MediaItem`.
- Queries chapter timing files and available speakers from `AudioService`.
- Logs diagnostics using app logging utilities.

## Verification
- Run: `flutter test`
