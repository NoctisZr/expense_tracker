import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/mod_theme.dart';
import '../utils/app_colors.dart';

/// Controla el modo oscuro/claro, el color de acento, el mod de
/// personalización activo (si hay uno) y la ruta de la imagen de fondo
/// personalizada.
class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'isDarkMode';
  static const String _accentColorKey = 'accentColorValue';
  static const String _modJsonKey = 'activeModJson';
  static const String _backgroundImagePathKey = 'backgroundImagePath';

  final Box settingsBox;

  late bool _isDarkMode;
  late Color _accentColor;
  ModTheme? _activeMod;
  String? _backgroundImagePath;

  ThemeProvider(this.settingsBox) {
    _isDarkMode = settingsBox.get(_darkModeKey, defaultValue: true) as bool;
    final int storedColorValue = settingsBox.get(
      _accentColorKey,
      defaultValue: AppColors.defaultAccent.toARGB32(),
    ) as int;
    _accentColor = Color(storedColorValue);
    _backgroundImagePath = settingsBox.get(_backgroundImagePathKey) as String?;

    final dynamic storedMod = settingsBox.get(_modJsonKey);
    if (storedMod is Map) {
      try {
        _activeMod = ModTheme.fromJson(Map<String, dynamic>.from(storedMod));
      } catch (_) {
        _activeMod = null;
      }
    }
  }

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;
  ModTheme? get activeMod => _activeMod;
  String? get backgroundImagePath => _backgroundImagePath;

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    settingsBox.put(_darkModeKey, value);
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    _activeMod = null;
    settingsBox.put(_accentColorKey, color.toARGB32());
    settingsBox.delete(_modJsonKey);
    notifyListeners();
  }

  void applyMod(ModTheme mod, Map<String, dynamic> rawJson) {
    _activeMod = mod;
    settingsBox.put(_modJsonKey, rawJson);
    if (mod.preferredBrightness != null) {
      _isDarkMode = mod.preferredBrightness == Brightness.dark;
      settingsBox.put(_darkModeKey, _isDarkMode);
    }
    notifyListeners();
  }

  void removeMod() {
    _activeMod = null;
    settingsBox.delete(_modJsonKey);
    notifyListeners();
  }

  void setBackgroundImagePath(String? path) {
    _backgroundImagePath = path;
    if (path == null) {
      settingsBox.delete(_backgroundImagePathKey);
    } else {
      settingsBox.put(_backgroundImagePathKey, path);
    }
    notifyListeners();
  }
}
