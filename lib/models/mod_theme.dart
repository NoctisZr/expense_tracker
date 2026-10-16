import 'package:flutter/material.dart';

/// Representa un "mod" de personalización: un archivo .json (creado por
/// el usuario o compartido por la comunidad) que redefine en detalle la
/// apariencia de la app — colores, forma, acentos y hasta una "máscara"
/// encima de todo — al estilo de cómo se personalizan los perfiles en
/// MyFigureCollection.
///
/// TODOS los campos son opcionales excepto "name": un mod puede cambiar
/// solo el acento, o redefinir la apariencia entera. Lo que no
/// especifique se completa con los valores por defecto de la app para
/// el modo (claro/oscuro) que esté activo. Ninguna de estas propiedades
/// es exclusiva de un mod en particular — cualquier mod puede usar
/// cualquier combinación de ellas.
///
/// Se limita intencionalmente a datos (colores, números, texto, y como
/// mucho una imagen ya-decodificable en base64), sin ejecutar ningún
/// código del archivo: una app Flutter se compila a binario nativo y
/// no tiene forma segura de "correr" código arbitrario que alguien más
/// escriba, así que un mod aquí es 100% seguro de cargar. Por la misma
/// razón, "style" y "overlay" solo pueden cambiar apariencia de
/// superficie — colores, formas geométricas nativas de Flutter, líneas
/// dibujadas o una imagen estática — nunca estructura, layout ni
/// lógica: nada de eso puede romper el funcionamiento interno de la
/// app, en el peor caso solo se ve raro.
class ModTheme {
  final String name;
  final String? author;
  final String? description;
  final Brightness? preferredBrightness;

  final Color? background;
  final Color? card;
  final Color? cardAlt;
  final Color? accent;
  final Color? accentSecondary;
  final Color? textPrimary;
  final Color? textSecondary;
  final Color? warning;
  final Color? expense;
  final Color? vault;
  final Color? success;
  final Color? danger;
  final Color? border;

  final double? cardRadius;
  final double? buttonRadius;

  /// "filled" (relleno sólido, por defecto) u "outlined" (transparente
  /// con borde).
  final String? cardStyle;

  /// "filled" (relleno sólido, por defecto), "outlined" (borde, sin
  /// relleno) o "text" (solo texto de color, sin fondo ni borde).
  final String? buttonStyle;

  /// "rounded" (esquinas curvas, por defecto), "beveled" (esquinas
  /// cortadas a 45°, como el filo de una hoja), "stadium" (óvalo
  /// completo/píldora) o "continuous" (curva suave tipo "squircle").
  final String? cardShape;
  final String? buttonShape;

  final double? borderWidth;
  final double? elevation;

  /// "compact", "comfortable" (por defecto) o "spacious".
  final String? density;

  /// "none" (por defecto) o "brackets" — pequeños corchetes
  /// decorativos en las esquinas de las tarjetas principales, estilo
  /// interfaz técnica/HUD.
  final String? cornerAccent;
  final Color? cornerAccentColor;

  /// La "máscara": un patrón liviano dibujado por código
  /// ("none"/"scanlines"/"grid", por defecto "none") o, si se da
  /// [overlayImageBase64], una imagen propia del mod — en ambos casos
  /// se dibuja semitransparente por ENCIMA de toda la app.
  final String? overlayPattern;
  final double? overlayOpacity;
  final String? overlayImageBase64;

  const ModTheme({
    required this.name,
    this.author,
    this.description,
    this.preferredBrightness,
    this.background,
    this.card,
    this.cardAlt,
    this.accent,
    this.accentSecondary,
    this.textPrimary,
    this.textSecondary,
    this.warning,
    this.expense,
    this.vault,
    this.success,
    this.danger,
    this.border,
    this.cardRadius,
    this.buttonRadius,
    this.cardStyle,
    this.buttonStyle,
    this.cardShape,
    this.buttonShape,
    this.borderWidth,
    this.elevation,
    this.density,
    this.cornerAccent,
    this.cornerAccentColor,
    this.overlayPattern,
    this.overlayOpacity,
    this.overlayImageBase64,
  });

  factory ModTheme.fromJson(Map<String, dynamic> json) {
    final dynamic rawName = json['name'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw const FormatException('El mod necesita un campo "name".');
    }

    final Map<String, dynamic> colors =
        (json['colors'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Map<String, dynamic> style =
        (json['style'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Map<String, dynamic> overlay =
        (json['overlay'] as Map?)?.cast<String, dynamic>() ?? const {};

    Brightness? brightness;
    if (json['preferredBrightness'] == 'light') brightness = Brightness.light;
    if (json['preferredBrightness'] == 'dark') brightness = Brightness.dark;

    String? pickEnum(String? value, List<String> allowed) =>
        allowed.contains(value) ? value : null;

    return ModTheme(
      name: rawName.trim(),
      author: (json['author'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      preferredBrightness: brightness,
      background: _parseHexColor(colors['background']),
      card: _parseHexColor(colors['card']),
      cardAlt: _parseHexColor(colors['cardAlt']),
      accent: _parseHexColor(colors['accent']),
      accentSecondary: _parseHexColor(colors['accentSecondary']),
      textPrimary: _parseHexColor(colors['textPrimary']),
      textSecondary: _parseHexColor(colors['textSecondary']),
      warning: _parseHexColor(colors['warning']),
      expense: _parseHexColor(colors['expense']),
      vault: _parseHexColor(colors['vault']),
      success: _parseHexColor(colors['success']),
      danger: _parseHexColor(colors['danger']),
      border: _parseHexColor(colors['border']),
      cardRadius: (style['cardRadius'] as num?)?.toDouble(),
      buttonRadius: (style['buttonRadius'] as num?)?.toDouble(),
      cardStyle: pickEnum(style['cardStyle'] as String?, const ['filled', 'outlined']),
      buttonStyle: pickEnum(style['buttonStyle'] as String?, const ['filled', 'outlined', 'text']),
      cardShape: pickEnum(
        style['cardShape'] as String?,
        const ['rounded', 'beveled', 'stadium', 'continuous'],
      ),
      buttonShape: pickEnum(
        style['buttonShape'] as String?,
        const ['rounded', 'beveled', 'stadium', 'continuous'],
      ),
      borderWidth: (style['borderWidth'] as num?)?.toDouble(),
      elevation: (style['elevation'] as num?)?.toDouble(),
      density: pickEnum(style['density'] as String?, const ['compact', 'comfortable', 'spacious']),
      cornerAccent: pickEnum(style['cornerAccent'] as String?, const ['none', 'brackets']),
      cornerAccentColor: _parseHexColor(style['cornerAccentColor']),
      overlayPattern: pickEnum(overlay['pattern'] as String?, const ['none', 'scanlines', 'grid']),
      overlayOpacity: (overlay['opacity'] as num?)?.toDouble(),
      overlayImageBase64: (overlay['imageBase64'] as String?)?.trim(),
    );
  }

  static Color? _parseHexColor(dynamic value) {
    if (value is! String) return null;
    String hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final int? parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
