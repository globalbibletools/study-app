// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get theme => 'المظهر';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get lightTheme => 'فاتح';

  @override
  String get darkTheme => 'داكن';

  @override
  String get about => 'حول';

  @override
  String get appName => 'أدوات الكتاب المقدس العالمية';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get emailCopied => 'تم نسخ البريد الإلكتروني';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get glossLanguage => 'لغة التفسير';

  @override
  String get bibleTranslation => 'ترجمة الكتاب المقدس';

  @override
  String get glossNone => 'لا شيء';

  @override
  String get currentLanguage => 'العربية';

  @override
  String get textSize => 'حجم النص';

  @override
  String get hebrewTextSize => 'العبرية';

  @override
  String get greekTextSize => 'اليونانية';

  @override
  String get secondPanelTextSize => 'اللوحة الثانية';

  @override
  String get lexiconTextSize => 'المعجم';

  @override
  String get verseLayout => 'تنسيق الآيات';

  @override
  String get paragraph => 'فقرة';

  @override
  String get versePerLine => 'آية في كل سطر';

  @override
  String get downloadResourcesMessage =>
      'لاستخدام هذه اللغة، نحتاج إلى تنزيل موارد إضافية.';

  @override
  String get download => 'تنزيل';

  @override
  String get cancel => 'إلغاء';

  @override
  String get gotIt => 'فهمت';

  @override
  String get readingCheckboxGuideTitle => 'تمييز الآيات كمقروءة';

  @override
  String get readingCheckboxGuideMessage =>
      'اضغط على مربع في كل مرة تقرأ فيها آية.';

  @override
  String get readingSessionGuideTitle => 'جلسات القراءة';

  @override
  String get readingSessionGuideMessage =>
      'تحفظ جلسات القراءة تقدمك وتساعدك على تحقيق أهدافك اليومية.';

  @override
  String get downloadComplete => 'اكتمل التنزيل.';

  @override
  String get downloadFailed =>
      'فشل التنزيل. يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى.';

  @override
  String get nextChapter => 'الإصحاح التالي';

  @override
  String get root => 'الجذر';

  @override
  String get exact => 'دقيق';

  @override
  String get search => 'بحث';

  @override
  String resultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتائج',
      one: 'نتيجة واحدة',
      zero: 'لا توجد نتائج',
    );
    return '$_temp0';
  }

  @override
  String get repeatNone => 'بدون';

  @override
  String get repeatVerse => 'تكرار الآية';

  @override
  String get repeatChapter => 'تكرار الإصحاح';

  @override
  String get audioRecordingSource => 'مصدر التسجيل';

  @override
  String get sourceHEB => 'شمولوڤ';

  @override
  String get sourceRDB => 'دان بيري';

  @override
  String get sourceTK => 'حديث';

  @override
  String get sourceJH => 'لوسيان';

  @override
  String get downloadAudio => 'تنزيل الصوت';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'الصوت لسفر $book الإصحاح $chapter غير موجود على جهازك.';
  }

  @override
  String get audioNotAvailable => 'الصوت غير متوفر لهذا الإصحاح.';

  @override
  String audioNotAvailableForChapter(String book, int chapter) {
    return 'الصوت غير متوفر لسفر $book الإصحاح $chapter';
  }

  @override
  String get unknownAudioError => 'خطأ غير معروف في الصوت';

  @override
  String get verseCopied => 'تم نسخ الآية إلى الحافظة';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get backupRestore => 'النسخ الاحتياطي/الاستعادة';

  @override
  String backupCreated(String path) {
    return 'تم إنشاء النسخة الاحتياطية: $path';
  }

  @override
  String get chooseBackupLocation => 'اختر موقع النسخة الاحتياطية';

  @override
  String backupExported(String path) {
    return 'تم تصدير النسخة الاحتياطية إلى $path';
  }

  @override
  String get selectBackupFile => 'حدد ملف النسخة الاحتياطية';

  @override
  String get couldNotReadSelectedBackupFile =>
      'تعذرت قراءة ملف النسخة الاحتياطية المحدد.';

  @override
  String backupImported(String name) {
    return 'تم استيراد $name';
  }

  @override
  String get restoreBackupQuestion => 'هل تريد استعادة النسخة الاحتياطية؟';

  @override
  String restoreBackupConfirmation(String name) {
    return 'سيؤدي هذا إلى استبدال بيانات جلسة القراءة الحالية بـ $name.';
  }

  @override
  String get restore => 'استعادة';

  @override
  String backupRestored(String name) {
    return 'تمت استعادة $name';
  }

  @override
  String appVersion(String version, String buildNumber) {
    return 'إصدار التطبيق $version ($buildNumber)';
  }

  @override
  String get createReadingSessionBackup => 'إنشاء نسخة احتياطية لجلسة القراءة';

  @override
  String get exportToFilesDrive => 'تصدير إلى الملفات / Drive';

  @override
  String get importFromFilesDrive => 'استيراد من الملفات / Drive';

  @override
  String get backupSystemPickerHelp =>
      'استخدم منتقي النظام للحفظ أو الاستعادة من مواقع مثل iCloud Drive أو Google Drive.';

  @override
  String get savedBackups => 'النسخ الاحتياطية المحفوظة';

  @override
  String get noBackupsCreatedYet => 'لم يتم إنشاء أي نسخ احتياطية بعد.';

  @override
  String bytesCount(int count) {
    return '$count بايت';
  }

  @override
  String get audio => 'الصوت';

  @override
  String get bibles => 'الكتاب المقدس';

  @override
  String get lexicons => 'المعاجم';

  @override
  String get glosses => 'التفاسير';

  @override
  String get oldTestament => 'العهد القديم';

  @override
  String get newTestament => 'العهد الجديد';

  @override
  String deleteAudioConfirmation(String book) {
    return 'هل تريد حذف جميع ملفات الصوت لسفر $book؟';
  }

  @override
  String get delete => 'حذف';

  @override
  String downloadAudioConfirmation(int count, String book) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هل تريد تنزيل $count إصحاحات مفقودة من $book؟',
      one: 'هل تريد تنزيل إصحاح واحد مفقود من $book؟',
    );
    return '$_temp0';
  }

  @override
  String get progress => 'التقدم';

  @override
  String get books => 'الأسفار';

  @override
  String get goals => 'الأهداف';

  @override
  String get bySection => 'حسب القسم';

  @override
  String get byBook => 'حسب السفر';

  @override
  String get christianOrder => 'الترتيب المسيحي';

  @override
  String get jewishOrder => 'الترتيب اليهودي';

  @override
  String get easyToHardOrder => 'من السهل إلى الصعب';

  @override
  String get week => 'أسبوع';

  @override
  String get month => 'شهر';

  @override
  String months(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': 'يناير',
      '2': 'فبراير',
      '3': 'مارس',
      '4': 'أبريل',
      '5': 'مايو',
      '6': 'يونيو',
      '7': 'يوليو',
      '8': 'أغسطس',
      '9': 'سبتمبر',
      '10': 'أكتوبر',
      '11': 'نوفمبر',
      '12': 'ديسمبر',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get startSession => 'ابدأ';

  @override
  String get start => 'ابدأ';

  @override
  String get resume => 'استئناف';

  @override
  String get whereYouLeftOff => 'من حيث توقفت';

  @override
  String get changeGoal => 'تغيير الهدف';

  @override
  String get setGoal => 'تعيين الهدف';

  @override
  String get chapterShort => 'فص';

  @override
  String get dailyGoal => 'الهدف اليومي';

  @override
  String get dailyGoalNotSet => 'الهدف اليومي: غير معين';

  @override
  String get minutes => 'دقائق';

  @override
  String get verses => 'آيات';

  @override
  String get minutesShort => 'د';

  @override
  String get versesShort => 'آ';

  @override
  String get dailyGoalReached => 'تم تحقيق الهدف اليومي';

  @override
  String get total => 'المجموع';

  @override
  String dayOfWeek(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      '1': 'الإثنين',
      '2': 'الثلاثاء',
      '3': 'الأربعاء',
      '4': 'الخميس',
      '5': 'الجمعة',
      '6': 'السبت',
      '7': 'الأحد',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get dismiss => 'إغلاق';

  @override
  String sessions(Object count) {
    return 'الجلسات: $count';
  }

  @override
  String get sessionTotal => 'مجموع الجلسة';

  @override
  String get inProgress => 'قيد التنفيذ';

  @override
  String get goalType => 'نوع الهدف';

  @override
  String get target => 'الهدف';

  @override
  String get save => 'حفظ';

  @override
  String get hide => 'إخفاء';

  @override
  String get show => 'إظهار';

  @override
  String get minutesPerDay => 'دقائق في اليوم';

  @override
  String get versesPerDay => 'آيات في اليوم';

  @override
  String get goalReachedMessage => 'لقد وصلت إلى هدفك 🎉';

  @override
  String get continueReadingPrompt => 'هل تريد متابعة جلسة القراءة؟';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get errorLoadingContent => 'تعذر تحميل المحتوى.';

  @override
  String errorLoadingVerse(String error) {
    return 'خطأ في تحميل الآية: $error';
  }

  @override
  String errorMessage(String error) {
    return 'خطأ: $error';
  }

  @override
  String downloadError(String error) {
    return 'خطأ في التنزيل: $error';
  }

  @override
  String get readingPlans => 'خطط القراءة';

  @override
  String get yourReadingPlans => 'خطط القراءة الخاصة بك';

  @override
  String get edit => 'تعديل';

  @override
  String get createNewPlan => 'إنشاء خطة جديدة';

  @override
  String get current => 'الحالي';

  @override
  String get startReading => 'بدء القراءة';

  @override
  String get resumeReading => 'متابعة القراءة';

  @override
  String booksReadOfTotal(int read, int total) {
    return 'الكتب: $read من $total';
  }

  @override
  String get todaysGoal => 'هدف اليوم';

  @override
  String get completedToday => 'اكتمل اليوم';

  @override
  String get estimatedCompletion => 'الإكمال المتوقع';

  @override
  String get planComplete => 'اكتملت الخطة!';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String monthsCount(String count) {
    return '($count شهر)';
  }

  @override
  String get booksInThisPlan => 'الكتب في هذه الخطة';

  @override
  String get done => 'تم';

  @override
  String get editOrder => 'تعديل الترتيب';

  @override
  String get defaultReadingPlanName => 'خطة 1';

  @override
  String get collection => 'المجموعة';

  @override
  String get goal => 'الهدف';

  @override
  String get planName => 'اسم الخطة';

  @override
  String get wholeBible => 'الكتاب المقدس كاملاً';

  @override
  String get torah => 'التوراة';

  @override
  String get prophets => 'الأنبياء';

  @override
  String get writings => 'الكتابات';

  @override
  String get gospels => 'الأناجيل';

  @override
  String get paulineEpistles => 'رسائل بولس';

  @override
  String allBooksSelected(int total) {
    return 'تم تحديد كل الكتب ($total)';
  }

  @override
  String booksSelected(int selected, int total) {
    return 'تم تحديد $selected/$total من الكتب';
  }

  @override
  String get updateReadingPlan => 'تحديث خطة القراءة';

  @override
  String get addReadingPlan => 'إضافة خطة قراءة';

  @override
  String get deselectAll => 'إلغاء تحديد الكل';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get selectAtLeastOneBook => 'حدد كتاباً واحداً على الأقل';

  @override
  String doneSelected(int count) {
    return 'تم ($count محدد)';
  }

  @override
  String bookCompletedTitle(String book) {
    return 'لقد أكملت $book!';
  }

  @override
  String get completed => 'مكتمل';

  @override
  String get nextBookInPlan => 'الكتاب التالي في الخطة';

  @override
  String get bookGenesis => 'التكوين';

  @override
  String get bookExodus => 'الخروج';

  @override
  String get bookLeviticus => 'اللاويين';

  @override
  String get bookNumbers => 'العدد';

  @override
  String get bookDeuteronomy => 'التثنية';

  @override
  String get bookJoshua => 'يشوع';

  @override
  String get bookJudges => 'القضاة';

  @override
  String get bookRuth => 'راعوث';

  @override
  String get book1Samuel => 'صموئيل الأول';

  @override
  String get book2Samuel => 'صموئيل الثاني';

  @override
  String get book1Kings => 'الملوك الأول';

  @override
  String get book2Kings => 'الملوك الثاني';

  @override
  String get book1Chronicles => 'أخبار الأيام الأول';

  @override
  String get book2Chronicles => 'أخبار الأيام الثاني';

  @override
  String get bookEzra => 'عزرا';

  @override
  String get bookNehemiah => 'نحميا';

  @override
  String get bookEsther => 'أستير';

  @override
  String get bookJob => 'أيوب';

  @override
  String get bookPsalms => 'المزامير';

  @override
  String get bookProverbs => 'الأمثال';

  @override
  String get bookEcclesiastes => 'الجامعة';

  @override
  String get bookSongOfSolomon => 'نشيد الأنشاد';

  @override
  String get bookIsaiah => 'إشعياء';

  @override
  String get bookJeremiah => 'إرميا';

  @override
  String get bookLamentations => 'مراثي إرميا';

  @override
  String get bookEzekiel => 'حزقيال';

  @override
  String get bookDaniel => 'دانيال';

  @override
  String get bookHosea => 'هوشع';

  @override
  String get bookJoel => 'يوئيل';

  @override
  String get bookAmos => 'عاموس';

  @override
  String get bookObadiah => 'عوبديا';

  @override
  String get bookJonah => 'يونان';

  @override
  String get bookMicah => 'ميخا';

  @override
  String get bookNahum => 'ناحوم';

  @override
  String get bookHabakkuk => 'حبقوق';

  @override
  String get bookZephaniah => 'صفنيا';

  @override
  String get bookHaggai => 'حجّي';

  @override
  String get bookZechariah => 'زكريا';

  @override
  String get bookMalachi => 'ملاخي';

  @override
  String get bookMatthew => 'متى';

  @override
  String get bookMark => 'مرقس';

  @override
  String get bookLuke => 'لوقا';

  @override
  String get bookJohn => 'يوحنا';

  @override
  String get bookActs => 'أعمال الرسل';

  @override
  String get bookRomans => 'رومية';

  @override
  String get book1Corinthians => 'كورنثوس الأولى';

  @override
  String get book2Corinthians => 'كورنثوس الثانية';

  @override
  String get bookGalatians => 'غلاطية';

  @override
  String get bookEphesians => 'أفسس';

  @override
  String get bookPhilippians => 'فيلبي';

  @override
  String get bookColossians => 'كولوسي';

  @override
  String get book1Thessalonians => 'تسالونيكي الأولى';

  @override
  String get book2Thessalonians => 'تسالونيكي الثانية';

  @override
  String get book1Timothy => 'تيموثاوس الأولى';

  @override
  String get book2Timothy => 'تيموثاوس الثانية';

  @override
  String get bookTitus => 'تيطس';

  @override
  String get bookPhilemon => 'فليمون';

  @override
  String get bookHebrews => 'العبرانيين';

  @override
  String get bookJames => 'يعقوب';

  @override
  String get book1Peter => 'بطرس الأولى';

  @override
  String get book2Peter => 'بطرس الثانية';

  @override
  String get book1John => 'يوحنا الأولى';

  @override
  String get book2John => 'يوحنا الثانية';

  @override
  String get book3John => 'يوحنا الثالثة';

  @override
  String get bookJude => 'يهوذا';

  @override
  String get bookRevelation => 'رؤيا يوحنا';
}
