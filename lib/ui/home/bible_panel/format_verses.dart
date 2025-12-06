// import 'package:database_builder/database_builder.dart';
// import 'package:flutter/widgets.dart';
// import 'package:studyapp/common/verse_line.dart';

// List<(TextSpan, TextType, Format?)> formatVerses({
//   required List<VerseLine> verseLines,
//   required double baseFontSize,
//   Color? textColor,
//   Color? verseNumberColor,
//   bool showVerseNumbers = true,
//   bool showSectionTitles = true,
// }) {
//   final mrTitleSize = baseFontSize * 1.2;
//   final msTitleSize = baseFontSize * 1.5;
//   final verseNumberSize = baseFontSize * 1.0;

//   final paragraphs = <(TextSpan, TextType, Format?)>[];
//   var verseSpans = <TextSpan>[];
//   int oldVerseNumber = 0;
//   Format oldFormat = Format.m;

//   for (var i = 0; i < verseLines.length; i++) {
//     final row = verseLines[i];
//     final type = row.type;
//     final format = row.format;
//     final text = row.text;
//     final verseNumber = row.verse;

//     if (type != TextType.v && verseSpans.isNotEmpty) {
//       paragraphs.add((TextSpan(children: verseSpans), TextType.v, oldFormat));
//       verseSpans = [];
//     }

//     switch (type) {
//       case TextType.v:
//         if (text == '\n') {
//           paragraphs.add((TextSpan(children: verseSpans), type, oldFormat));
//           verseSpans = [];
//           break;
//         }

//         // add verse number
//         if (showVerseNumbers && oldVerseNumber != verseNumber) {
//           oldVerseNumber = verseNumber;
//           if (verseSpans.isNotEmpty) {
//             verseSpans.add(TextSpan(text: ' '));
//           }
//           verseSpans.add(
//             TextSpan(
//               // Use NNBSP so the verse number is not separated from the verse text.
//               text: '$verseNumber\u202f\u202f',
//               style: TextStyle(
//                 fontSize: verseNumberSize,
//                 color: verseNumberColor,
//                 fontWeight: FontWeight.bold,
//                 fontFeatures: const [FontFeature.superscripts()],
//               ),
//             ),
//           );
//         }
//         // add verse line text
//         if (format == Format.qr) {
//           verseSpans.add(
//             TextSpan(
//               text: text,
//               style: TextStyle(
//                 fontSize: baseFontSize,
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           );
//         } else {
//           verseSpans.add(
//             TextSpan(text: text, style: TextStyle(fontSize: baseFontSize)),
//           );
//         }

//         // handle poetry
//         if (format == Format.q1 || format == Format.q2 || format == Format.qr) {
//           paragraphs.add((TextSpan(children: verseSpans), type, format));
//           verseSpans = [];
//         }
//         oldFormat = format ?? Format.m;

//       case TextType.d:
//         final verseSpans = <TextSpan>[];
//         verseSpans.add(
//           TextSpan(text: text, style: TextStyle(fontSize: baseFontSize)),
//         );
//         paragraphs.add((TextSpan(children: verseSpans), type, format));

//       case TextType.r:
//         // Skip because cross references are now handled in TextType.s1
//         break;

//       case TextType.s1:
//         if (!showSectionTitles) break;
//         final spans = <TextSpan>[];
//         spans.add(
//           TextSpan(
//             text: text,
//             style: TextStyle(
//               fontSize: baseFontSize,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         );
//         paragraphs.add((TextSpan(children: spans), type, format));

//       case TextType.s2:
//         if (!showSectionTitles) break;
//         paragraphs.add((
//           TextSpan(
//             text: text,
//             style: TextStyle(
//               fontSize: baseFontSize,
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//           type,
//           format,
//         ));

//       case TextType.ms:
//         if (!showSectionTitles) break;
//         paragraphs.add((
//           TextSpan(
//             text: text,
//             style: TextStyle(
//               fontSize: msTitleSize,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           type,
//           format,
//         ));

//       case TextType.mr:
//         if (!showSectionTitles) break;
//         paragraphs.add((
//           TextSpan(
//             text: text,
//             style: TextStyle(
//               fontSize: mrTitleSize,
//               color: textColor,
//               fontStyle: FontStyle.italic,
//             ),
//           ),
//           type,
//           format,
//         ));

//       case TextType.qa:
//         if (!showSectionTitles) break;
//         paragraphs.add((
//           TextSpan(
//             text: text,
//             style: TextStyle(
//               fontSize: baseFontSize,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           type,
//           format,
//         ));
//     }
//   }

//   if (verseSpans.isNotEmpty) {
//     paragraphs.add((TextSpan(children: verseSpans), TextType.v, oldFormat));
//   }

//   return paragraphs;
// }
