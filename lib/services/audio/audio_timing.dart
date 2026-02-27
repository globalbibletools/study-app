class AudioTiming {
  final int verseId;
  final double start;
  final double end;
  final int version;

  AudioTiming({
    required this.verseId,
    required this.start,
    required this.end,
    required this.version,
  });

  factory AudioTiming.fromMap(Map<String, dynamic> map) {
    return AudioTiming(
      verseId: map['verse_id'] as int,
      start: map['start'] as double,
      end: map['end'] as double? ?? double.infinity,
      version: map['version'] as int? ?? 1,
    );
  }
}
