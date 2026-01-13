import 'package:studyapp/ui/home/audio/audio_manager.dart';

class AudioLogic {
  // Books 1-39 are OT. 40-66 are NT.
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

  // NT Books that have audio content (GNT)
  // 41 (Mark), 51 (Col), 57 (Phm), 59 (Jas), 62 (1Jn)
  static const Set<int> _availableNtBooks = {41, 51, 57, 59, 62};

  static bool isNewTestament(int bookId) {
    return bookId >= _firstNtBook;
  }

  static bool hasTimingData(int bookId) {
    // NT has no timing data.
    return !isNewTestament(bookId);
  }

  /// Checks if Rabbi Dan Beeri audio exists for this specific book
  static bool isRdbAvailableForBook(int bookId) {
    if (isNewTestament(bookId)) return false;
    return !_missingRdbBooks.contains(bookId);
  }

  /// Checks if audio is generally available for a book/chapter.
  /// Used to prevent 404s on downloads for content that doesn't exist on server.
  static bool isAudioAvailable(int bookId, int chapter) {
    // Old Testament is always available (at least via HEB)
    if (!isNewTestament(bookId)) return true;

    // Matthew (40) only has chapters 1-19
    if (bookId == 40) {
      return chapter <= 19;
    }

    // Other NT books check the whitelist
    return _availableNtBooks.contains(bookId);
  }

  /// Determines the actual folder/recording ID to use based on book and preference.
  static String getRecordingId(int bookId, AudioSourceType userPreference) {
    // 1. New Testament Logic
    if (isNewTestament(bookId)) {
      return 'GNT'; // Greek New Testament folder
    }

    // 2. Old Testament Logic
    // If the user wants RDB, but it's missing, force HEB.
    if (userPreference == AudioSourceType.rdb) {
      if (_missingRdbBooks.contains(bookId)) {
        return 'HEB';
      }
      return 'RDB';
    }

    // Default to HEB if preferred
    return 'HEB';
  }
}
