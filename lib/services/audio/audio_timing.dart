class AudioTiming {
  final int verseId;
  final double start;
  final double end;

  AudioTiming({required this.verseId, required this.start, required this.end});

  int get verseNumber => verseId % 1000;

  factory AudioTiming.fromMap(Map<String, dynamic> map) {
    return AudioTiming(
      verseId: map['verse_id'] as int,
      start: map['start'] as double,
      // If null in DB, it plays to the end of the file
      end: map['end'] as double? ?? double.infinity,
    );
  }
}
