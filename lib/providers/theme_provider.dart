import 'dart:convert';
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
  static const String _textScaleKey = 'textScale';
  static const String _userModsKey = 'userMods';
  static const String _simpleModeKey = 'simpleMode';

  final Box settingsBox;

  late bool _isDarkMode;
  late Color _accentColor;
  ModTheme? _activeMod;
  String? _backgroundImagePath;
  double _textScale = 1.0;
  bool _simpleMode = false;

  ThemeProvider(this.settingsBox) {
    _isDarkMode = settingsBox.get(_darkModeKey, defaultValue: true) as bool;
    final int storedColorValue = settingsBox.get(
      _accentColorKey,
      defaultValue: AppColors.defaultAccent.toARGB32(),
    ) as int;
    _accentColor = Color(storedColorValue);
    _backgroundImagePath = settingsBox.get(_backgroundImagePathKey) as String?;
    _simpleMode = settingsBox.get(_simpleModeKey, defaultValue: false) == true;
    final dynamic storedScale = settingsBox.get(_textScaleKey);
    if (storedScale is num) _textScale = storedScale.toDouble().clamp(0.85, 1.4).toDouble();

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

  /// Mods guardados por el usuario (creados con el editor, pegados o
  /// cargados desde un archivo). Cada uno es el JSON del mod.
  List<Map<String, dynamic>> get userMods {
    final dynamic raw = settingsBox.get(_userModsKey);
    final List<Map<String, dynamic>> result = [];
    if (raw is List) {
      for (final item in raw) {
        try {
          final dynamic decoded = json.decode(json.encode(item));
          if (decoded is Map && decoded['name'] is String) {
            result.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
    }
    return result;
  }

  /// Guarda (o reemplaza, si ya existe uno con ese nombre) un mod propio.
  Future<void> saveUserMod(Map<String, dynamic> modJson) async {
    final String name = (modJson['name'] as String).trim();
    final List<Map<String, dynamic>> list =
        userMods.where((m) => (m['name'] as String).trim() != name).toList()..add(modJson);
    await settingsBox.put(_userModsKey, list);
    notifyListeners();
  }

  Future<void> deleteUserMod(String name) async {
    final List<Map<String, dynamic>> list =
        userMods.where((m) => (m['name'] as String).trim() != name.trim()).toList();
    await settingsBox.put(_userModsKey, list);
    notifyListeners();
  }

  /// Multiplicador del tamaño de texto (0.85 – 1.4), sumado al del sistema.
  double get textScale => _textScale;

  void setTextScale(double value) {
    _textScale = value.clamp(0.85, 1.4).toDouble();
    settingsBox.put(_textScaleKey, _textScale);
    notifyListeners();
  }

  /// Modo simple: letra más grande y solo lo básico (sin Planificación ni análisis).
  bool get simpleMode => _simpleMode;

  void setSimpleMode(bool value) {
    _simpleMode = value;
    settingsBox.put(_simpleModeKey, value);
    notifyListeners();
  }

  /// Tamaño de letra realmente aplicado (el modo simple exige al menos 1.25).
  double get effectiveTextScale => _simpleMode && _textScale < 1.25 ? 1.25 : _textScale;

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
