import 'package:studyapp/ui/home/audio/audio_manager.dart';

class AudioLogic {
  static const int _firstNtBook = 40;

  // Specific OT books completely missing from the RDB collection
  static const Set<int> _missingRdbBooks = {
    13, // 1 Chronicles
    14, // 2 Chronicles
    16, // Nehemiah
    24, // Jeremiah
    26, // Ezekiel
    28, // Hosea
    29, // Joel
    30, // Amos
    33, // Micah
  };

  static bool isNewTestament(int bookId) {
    return bookId >= _firstNtBook;
  }

  static bool hasTimingData(int bookId) {
    // Because you added NT data to the database, ALL books now have timing!
    return true;
  }

  // Book-level check: is RDB available for ANY chapter in this book?
  static bool isRdbAvailableForBook(int bookId) {
    if (isNewTestament(bookId)) return false;
    return !_missingRdbBooks.contains(bookId);
  }

  // Chapter-level check: is RDB available for this specific chapter?
  static bool isRdbAvailable(int bookId, int chapter) {
    if (!isRdbAvailableForBook(bookId)) return false;

    // Ezra: missing Chapters 8-10
    if (bookId == 15 && chapter >= 8 && chapter <= 10) return false;
    // Psalms: missing Chapters 50-112
    if (bookId == 19 && chapter >= 50 && chapter <= 112) return false;
    // Isaiah: missing Chapters 38-66
    if (bookId == 23 && chapter >= 38 && chapter <= 66) return false;
    // Malachi: missing Chapters 3-4
    if (bookId == 39 && chapter >= 3 && chapter <= 4) return false;
    // Nahum 1:1-1:9 is partial, so we permit Chapter 1.
    // It will sync with whatever timings/content exist natively.

    return true;
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

  /// Determines the actual folder/recording ID to use based on book, chapter, and preference.
  static String getRecordingId(
    int bookId,
    int chapter,
    AudioSourceType userPreference,
  ) {
    // 1. New Testament Logic
    if (isNewTestament(bookId)) {
      if (userPreference == AudioSourceType.tk) return 'TK';
      if (userPreference == AudioSourceType.jh &&
          isJhAvailableForBook(bookId)) {
        return 'JH';
      }

      // Default for NT: JH if Matthew, otherwise TK
      return isJhAvailableForBook(bookId) ? 'JH' : 'TK';
    }

    // 2. Old Testament Logic
    if (userPreference == AudioSourceType.rdb &&
        isRdbAvailable(bookId, chapter)) {
      return 'RDB';
    }

    // Default for OT
    return 'HEB';
  }
}
