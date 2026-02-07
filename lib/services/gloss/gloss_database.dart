import 'dart:developer';
import 'package:database_builder/database_builder.dart'; // Assuming this is where GlossSchema lives
import 'package:sqflite/sqflite.dart';
import 'package:studyapp/l10n/app_languages.dart';
import 'package:studyapp/services/files/file_service.dart';
import 'package:studyapp/services/service_locator.dart';

class GlossDatabase {
  final _fileService = getIt<FileService>();

  Database? _database;
  String _currentLangCode = '';

  String getDbFilename(String langCode) {
    return AppLanguages.getConfig(langCode).glossFilename;
  }

  Future<bool> glossDbExists(String langCode) async {
    final filename = getDbFilename(langCode);
    return _fileService.checkFileExists(FileType.gloss, filename);
  }

  Future<void> initDb(String langCode) async {
    if (langCode == 'en' || _currentLangCode == langCode) {
      return;
    }

    final filename = getDbFilename(langCode);
    final exists = await _fileService.checkFileExists(FileType.gloss, filename);

    if (!exists) {
      log('Database for $langCode does not exist at $filename');
      return;
    }

    if (_database != null) {
      await _database?.close();
      _database = null;
      _currentLangCode = '';
    }

    // Get the absolute path from FileService to open the DB
    final path = await _fileService.getLocalPath(FileType.gloss, filename);

    try {
      _database = await openDatabase(path, readOnly: true);
      _currentLangCode = langCode;
    } catch (e) {
      log("Error opening gloss DB: $e");
    }
  }

  Future<String?> getGloss(String langCode, int wordId) async {
    // Ensure DB is open for this language
    if (_database == null || _currentLangCode != langCode) {
      await initDb(langCode);
    }

    // If still null, we failed to open (likely not downloaded)
    if (_database == null) return null;

    try {
      final query =
          '''
        SELECT t.${GlossSchema.textColText}
        FROM ${GlossSchema.versesTable} v
        JOIN ${GlossSchema.textTable} t 
        ON v.${GlossSchema.versesColText} = t.${GlossSchema.textColId}
        WHERE v.${GlossSchema.versesColId} = ?
        ''';
      final List<Map<String, dynamic>> words = await _database!.rawQuery(
        query,
        [wordId],
      );
      if (words.isEmpty) return null;
      return words.first[GlossSchema.textColText] as String?;
    } catch (e, s) {
      log('Error getting gloss for $langCode', error: e, stackTrace: s);
      return null;
    }
  }
}
