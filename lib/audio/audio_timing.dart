class AudioTiming {
  final int verseId;
  final double start;
  final double end;

  AudioTiming({required this.verseId, required this.start, required this.end});

  int get verseNumber => verseId % 1000;
}
