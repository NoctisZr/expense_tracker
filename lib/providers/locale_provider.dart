import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../l10n/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _languageKey = 'languageCode';

  final Box settingsBox;

  late String _languageCode;

  LocaleProvider(this.settingsBox) {
    final dynamic stored = settingsBox.get(_languageKey);
    if (stored is String) {
      _languageCode = stored;
    } else {
      // Primer arranque: idioma del teléfono (es / en / pt), con español
      // como respaldo.
      final String deviceLanguage =
          PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      _languageCode = const ['es', 'en', 'pt'].contains(deviceLanguage)
          ? deviceLanguage
          : 'es';
      settingsBox.put(_languageKey, _languageCode);
    }
  }

  String get languageCode => _languageCode;

  void setLanguage(String code) {
    _languageCode = code;
    settingsBox.put(_languageKey, code);
    notifyListeners();
  }

  String t(String key) => AppStrings.get(_languageCode, key);
}
