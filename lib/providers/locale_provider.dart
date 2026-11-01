import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../l10n/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _languageKey = 'languageCode';
  static const String _autoFallbackKey = 'languageAutoFallback';

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
      final bool supported = const ['es', 'en', 'pt'].contains(deviceLanguage);
      _languageCode = supported ? deviceLanguage : 'es';
      settingsBox.put(_languageKey, _languageCode);
      // Si el idioma del teléfono no está disponible, se marca para que el
      // país detectado por IP pueda elegir uno mejor (solo esa vez).
      if (!supported) settingsBox.put(_autoFallbackKey, true);
    }
  }

  String get languageCode => _languageCode;

  /// Usa el idioma del país detectado, solo si el del teléfono no estaba
  /// disponible y el usuario no eligió uno. Devuelve si lo cambió.
  bool applyRegionLanguage(String code) {
    if (settingsBox.get(_autoFallbackKey) != true) return false;
    if (!const ['es', 'en', 'pt'].contains(code)) return false;
    _languageCode = code;
    settingsBox.put(_languageKey, code);
    settingsBox.delete(_autoFallbackKey);
    notifyListeners();
    return true;
  }

  void setLanguage(String code) {
    settingsBox.delete(_autoFallbackKey);
    _languageCode = code;
    settingsBox.put(_languageKey, code);
    notifyListeners();
  }

  String t(String key) => AppStrings.get(_languageCode, key);
}
