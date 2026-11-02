import 'dart:ui' show TextDirection;

import 'package:gbt/services/resources/resource_language.dart';

extension ResourceLanguageTextDirectionX on ResourceLanguageTextDirection {
  TextDirection get toTextDirection => switch (this) {
    ResourceLanguageTextDirection.ltr => TextDirection.ltr,
    ResourceLanguageTextDirection.rtl => TextDirection.rtl,
  };
}
