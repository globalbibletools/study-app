import 'package:flutter/widgets.dart';
import 'package:gbt/l10n/app_localizations.dart';

String bookNameFromId(BuildContext context, int bookId) {
  return bookNameFromLocalizations(AppLocalizations.of(context)!, bookId);
}

String bookNameFromLocalizations(AppLocalizations l, int bookId) {
  switch (bookId) {
    case 1:
      return l.bookGenesis;
    case 2:
      return l.bookExodus;
    case 3:
      return l.bookLeviticus;
    case 4:
      return l.bookNumbers;
    case 5:
      return l.bookDeuteronomy;
    case 6:
      return l.bookJoshua;
    case 7:
      return l.bookJudges;
    case 8:
      return l.bookRuth;
    case 9:
      return l.book1Samuel;
    case 10:
      return l.book2Samuel;
    case 11:
      return l.book1Kings;
    case 12:
      return l.book2Kings;
    case 13:
      return l.book1Chronicles;
    case 14:
      return l.book2Chronicles;
    case 15:
      return l.bookEzra;
    case 16:
      return l.bookNehemiah;
    case 17:
      return l.bookEsther;
    case 18:
      return l.bookJob;
    case 19:
      return l.bookPsalms;
    case 20:
      return l.bookProverbs;
    case 21:
      return l.bookEcclesiastes;
    case 22:
      return l.bookSongOfSolomon;
    case 23:
      return l.bookIsaiah;
    case 24:
      return l.bookJeremiah;
    case 25:
      return l.bookLamentations;
    case 26:
      return l.bookEzekiel;
    case 27:
      return l.bookDaniel;
    case 28:
      return l.bookHosea;
    case 29:
      return l.bookJoel;
    case 30:
      return l.bookAmos;
    case 31:
      return l.bookObadiah;
    case 32:
      return l.bookJonah;
    case 33:
      return l.bookMicah;
    case 34:
      return l.bookNahum;
    case 35:
      return l.bookHabakkuk;
    case 36:
      return l.bookZephaniah;
    case 37:
      return l.bookHaggai;
    case 38:
      return l.bookZechariah;
    case 39:
      return l.bookMalachi;
    case 40:
      return l.bookMatthew;
    case 41:
      return l.bookMark;
    case 42:
      return l.bookLuke;
    case 43:
      return l.bookJohn;
    case 44:
      return l.bookActs;
    case 45:
      return l.bookRomans;
    case 46:
      return l.book1Corinthians;
    case 47:
      return l.book2Corinthians;
    case 48:
      return l.bookGalatians;
    case 49:
      return l.bookEphesians;
    case 50:
      return l.bookPhilippians;
    case 51:
      return l.bookColossians;
    case 52:
      return l.book1Thessalonians;
    case 53:
      return l.book2Thessalonians;
    case 54:
      return l.book1Timothy;
    case 55:
      return l.book2Timothy;
    case 56:
      return l.bookTitus;
    case 57:
      return l.bookPhilemon;
    case 58:
      return l.bookHebrews;
    case 59:
      return l.bookJames;
    case 60:
      return l.book1Peter;
    case 61:
      return l.book2Peter;
    case 62:
      return l.book1John;
    case 63:
      return l.book2John;
    case 64:
      return l.book3John;
    case 65:
      return l.bookJude;
    case 66:
      return l.bookRevelation;

    default:
      return '';
  }
}

String orgBookNameFromId(int bookId) {
  switch (bookId) {
    case 1:
      return "בְּרֵאשִׁית";
    case 2:
      return "שְׁמוֹת";
    case 3:
      return "וַיִּקְרָא";
    case 4:
      return "בְּמִדְבַּר";
    case 5:
      return "דְּבָרִים";
    case 6:
      return "יְהוֹשֻׁעַ";
    case 7:
      return "שֹׁפְטִים";
    case 8:
      return "רוּת";
    case 9:
      return "שְׁמוּאֵל א";
    case 10:
      return "שְׁמוּאֵל ב";
    case 11:
      return "מְלָכִים א";
    case 12:
      return "מְלָכִים ב";
    case 13:
      return "דִּבְרֵי הַיָּמִים א";
    case 14:
      return "דִּבְרֵי הַיָּמִים ב";
    case 15:
      return "עֶזְרָא";
    case 16:
      return "נְחֶמְיָה";
    case 17:
      return "אֶסְתֵּר";
    case 18:
      return "אִיּוֹב";
    case 19:
      return "תְּהִלִּים";
    case 20:
      return "מִשְׁלֵי";
    case 21:
      return "קֹהֶלֶת";
    case 22:
      return "שִׁיר הַשִּׁירִים";
    case 23:
      return "יְשַׁעְיָהוּ";
    case 24:
      return "יִרְמְיָהוּ";
    case 25:
      return "אֵיכָה";
    case 26:
      return "יְחֶזְקֵאל";
    case 27:
      return "דָּנִיֵּאל";
    case 28:
      return "הוֹשֵׁעַ";
    case 29:
      return "יוֹאֵל";
    case 30:
      return "עָמוֹס";
    case 31:
      return "עֹבַדְיָה";
    case 32:
      return "יוֹנָה";
    case 33:
      return "מִיכָה";
    case 34:
      return "נַחוּם";
    case 35:
      return "חֲבַקּוּק";
    case 36:
      return "צְפַנְיָה";
    case 37:
      return "חַגַּי";
    case 38:
      return "זְכַרְיָה";
    case 39:
      return "מַלְאָכִי";
    case 40:
      return "Κατὰ Μαθθαῖον";
    case 41:
      return "Κατὰ Μᾶρκον";
    case 42:
      return "Κατὰ Λουκᾶν";
    case 43:
      return "Κατὰ Ἰωάννην";
    case 44:
      return "Πράξεις Ἀποστόλων";
    case 45:
      return "Πρὸς Ῥωμαίους";
    case 46:
      return "Πρὸς Κορινθίους Α΄";
    case 47:
      return "Πρὸς Κορινθίους Β΄";
    case 48:
      return "Πρὸς Γαλάτας";
    case 49:
      return "Πρὸς Ἐφεσίους";
    case 50:
      return "Πρὸς Φιλιππησίους";
    case 51:
      return "Πρὸς Κολοσσαεῖς";
    case 52:
      return "Πρὸς Θεσσαλονικεῖς Α΄";
    case 53:
      return "Πρὸς Θεσσαλονικεῖς Β΄";
    case 54:
      return "Πρὸς Τιμόθεον Α΄";
    case 55:
      return "Πρὸς Τιμόθεον Β΄";
    case 56:
      return "Πρὸς Τίτον";
    case 57:
      return "Πρὸς Φιλήμονα";
    case 58:
      return "Πρὸς Ἑβραίους";
    case 59:
      return "Ἰακώβου";
    case 60:
      return "Πέτρου Α΄";
    case 61:
      return "Πέτρου Β΄";
    case 62:
      return "Ἰωάννου Α΄";
    case 63:
      return "Ἰωάννου Β΄";
    case 64:
      return "Ἰωάννου Γ΄";
    case 65:
      return "Ἰούδα";
    case 66:
      return "Ἀποκάλυψις Ἰωάννου";

    default:
      return '';
  }
}
