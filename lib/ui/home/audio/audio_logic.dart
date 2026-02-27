import 'package:studyapp/ui/home/audio/audio_manager.dart';

class AudioLogic {
  static const int _firstNtBook = 40;

  // Specific OT books missing from the RDB collection
  static const Set<int> _missingRdbBooks = {
    13,
    14,
    16,
    24,
    26,
    28,
    29,
    30,
    33,
    39,
  };

  static bool isNewTestament(int bookId) {
    return bookId >= _firstNtBook;
  }

  static bool hasTimingData(int bookId) {
    // Because you added NT data to the database, ALL books now have timing!
    return true;
  }

  static bool isRdbAvailableForBook(int bookId) {
    if (isNewTestament(bookId)) return false;
    return !_missingRdbBooks.contains(bookId);
  }

  /// JH is currently only available for Matthew
  static bool isJhAvailableForBook(int bookId) {
    return bookId == 40;
  }

  static bool isAudioAvailable(int bookId, int chapter) {
    // Every book/chapter now has at least one audio source available
    // (OT defaults to HEB, NT defaults to TK)
    return true;
  }

  /// Determines the actual folder/recording ID to use based on book and preference.
  static String getRecordingId(int bookId, AudioSourceType userPreference) {
    // 1. New Testament Logic
    if (isNewTestament(bookId)) {
      if (userPreference == AudioSourceType.tk) return 'TK';
      if (userPreference == AudioSourceType.jh && isJhAvailableForBook(bookId))
        return 'JH';

      // Default for NT: JH if Matthew, otherwise TK
      return isJhAvailableForBook(bookId) ? 'JH' : 'TK';
    }

    // 2. Old Testament Logic
    if (userPreference == AudioSourceType.rdb &&
        isRdbAvailableForBook(bookId)) {
      return 'RDB';
    }

    // Default for OT
    return 'HEB';
  }
}
