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
  String get downloadResourcesMessage =>
      'لاستخدام هذه اللغة، نحتاج إلى تنزيل موارد إضافية.';

  @override
  String get useEnglish => 'استخدام الإنجليزية';

  @override
  String get download => 'تنزيل';

  @override
  String get cancel => 'إلغاء';

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
  String get downloadAudio => 'تنزيل الصوت';

  @override
  String audioNotDownloaded(String book, int chapter) {
    return 'الصوت لسفر $book الإصحاح $chapter غير موجود على جهازك.';
  }

  @override
  String get audioNotAvailable => 'الصوت غير متوفر لهذا الإصحاح.';

  @override
  String get verseCopied => 'تم نسخ الآية إلى الحافظة';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get audio => 'الصوت';

  @override
  String get bibles => 'الكتاب المقدس';

  @override
  String get lexicons => 'المعاجم';

  @override
  String get oldTestament => 'العهد القديم';

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
