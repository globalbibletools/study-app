import 'package:flutter/foundation.dart';
import 'package:studyapp/services/database.dart';
import 'package:studyapp/services/service_locator.dart';

class HomeManager {
  final textNotifier = ValueNotifier('');
  final db = getIt<HebrewGreekDatabase>();

  Future<void> init() async {
    final words = await db.getChapter(1, 1);
    textNotifier.value = words.map((e) => e.text).join(' ');
  }
}
