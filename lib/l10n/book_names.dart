import 'package:flutter/widgets.dart';
import 'package:gbt/l10n/app_localizations.dart';

String bookNameFromId(BuildContext context, int bookId) {
  switch (bookId) {
    case 1:
      return AppLocalizations.of(context)!.bookGenesis;
    case 2:
      return AppLocalizations.of(context)!.bookExodus;
    case 3:
      return AppLocalizations.of(context)!.bookLeviticus;
    case 4:
      return AppLocalizations.of(context)!.bookNumbers;
    case 5:
      return AppLocalizations.of(context)!.bookDeuteronomy;
    case 6:
      return AppLocalizations.of(context)!.bookJoshua;
    case 7:
      return AppLocalizations.of(context)!.bookJudges;
    case 8:
      return AppLocalizations.of(context)!.bookRuth;
    case 9:
      return AppLocalizations.of(context)!.book1Samuel;
    case 10:
      return AppLocalizations.of(context)!.book2Samuel;
    case 11:
      return AppLocalizations.of(context)!.book1Kings;
    case 12:
      return AppLocalizations.of(context)!.book2Kings;
    case 13:
      return AppLocalizations.of(context)!.book1Chronicles;
    case 14:
      return AppLocalizations.of(context)!.book2Chronicles;
    case 15:
      return AppLocalizations.of(context)!.bookEzra;
    case 16:
      return AppLocalizations.of(context)!.bookNehemiah;
    case 17:
      return AppLocalizations.of(context)!.bookEsther;
    case 18:
      return AppLocalizations.of(context)!.bookJob;
    case 19:
      return AppLocalizations.of(context)!.bookPsalms;
    case 20:
      return AppLocalizations.of(context)!.bookProverbs;
    case 21:
      return AppLocalizations.of(context)!.bookEcclesiastes;
    case 22:
      return AppLocalizations.of(context)!.bookSongOfSolomon;
    case 23:
      return AppLocalizations.of(context)!.bookIsaiah;
    case 24:
      return AppLocalizations.of(context)!.bookJeremiah;
    case 25:
      return AppLocalizations.of(context)!.bookLamentations;
    case 26:
      return AppLocalizations.of(context)!.bookEzekiel;
    case 27:
      return AppLocalizations.of(context)!.bookDaniel;
    case 28:
      return AppLocalizations.of(context)!.bookHosea;
    case 29:
      return AppLocalizations.of(context)!.bookJoel;
    case 30:
      return AppLocalizations.of(context)!.bookAmos;
    case 31:
      return AppLocalizations.of(context)!.bookObadiah;
    case 32:
      return AppLocalizations.of(context)!.bookJonah;
    case 33:
      return AppLocalizations.of(context)!.bookMicah;
    case 34:
      return AppLocalizations.of(context)!.bookNahum;
    case 35:
      return AppLocalizations.of(context)!.bookHabakkuk;
    case 36:
      return AppLocalizations.of(context)!.bookZephaniah;
    case 37:
      return AppLocalizations.of(context)!.bookHaggai;
    case 38:
      return AppLocalizations.of(context)!.bookZechariah;
    case 39:
      return AppLocalizations.of(context)!.bookMalachi;
    case 40:
      return AppLocalizations.of(context)!.bookMatthew;
    case 41:
      return AppLocalizations.of(context)!.bookMark;
    case 42:
      return AppLocalizations.of(context)!.bookLuke;
    case 43:
      return AppLocalizations.of(context)!.bookJohn;
    case 44:
      return AppLocalizations.of(context)!.bookActs;
    case 45:
      return AppLocalizations.of(context)!.bookRomans;
    case 46:
      return AppLocalizations.of(context)!.book1Corinthians;
    case 47:
      return AppLocalizations.of(context)!.book2Corinthians;
    case 48:
      return AppLocalizations.of(context)!.bookGalatians;
    case 49:
      return AppLocalizations.of(context)!.bookEphesians;
    case 50:
      return AppLocalizations.of(context)!.bookPhilippians;
    case 51:
      return AppLocalizations.of(context)!.bookColossians;
    case 52:
      return AppLocalizations.of(context)!.book1Thessalonians;
    case 53:
      return AppLocalizations.of(context)!.book2Thessalonians;
    case 54:
      return AppLocalizations.of(context)!.book1Timothy;
    case 55:
      return AppLocalizations.of(context)!.book2Timothy;
    case 56:
      return AppLocalizations.of(context)!.bookTitus;
    case 57:
      return AppLocalizations.of(context)!.bookPhilemon;
    case 58:
      return AppLocalizations.of(context)!.bookHebrews;
    case 59:
      return AppLocalizations.of(context)!.bookJames;
    case 60:
      return AppLocalizations.of(context)!.book1Peter;
    case 61:
      return AppLocalizations.of(context)!.book2Peter;
    case 62:
      return AppLocalizations.of(context)!.book1John;
    case 63:
      return AppLocalizations.of(context)!.book2John;
    case 64:
      return AppLocalizations.of(context)!.book3John;
    case 65:
      return AppLocalizations.of(context)!.bookJude;
    case 66:
      return AppLocalizations.of(context)!.bookRevelation;

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
