import 'package:flutter/material.dart';
import '../models/mod_theme.dart';

/// "#RRGGBB" de un color (sin transparencia).
String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Interpreta "#RRGGBB", "RRGGBB", "#RGB" o "RGB". Devuelve `null` si no es válido.
Color? parseHexColor(String input) {
  String hex = input.trim().replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length != 6) return null;
  final int? value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Formas de tarjeta disponibles en el editor.
const List<String> kModShapes = ['rounded', 'stadium', 'beveled', 'continuous'];

double _radiusForShape(String shape) {
  switch (shape) {
    case 'stadium':
      return 24;
    case 'beveled':
      return 12;
    case 'continuous':
      return 20;
    case 'rounded':
    default:
      return 16;
  }
}

/// Borrador de un mod creado con el editor. Con solo elegir un color de
/// acento y "oscuro/claro" se genera una paleta completa y legible; después
/// cada color se puede ajustar a mano.
class ModDraft {
  String name;
  String author;
  bool dark;
  Color background;
  Color card;
  Color accent;
  Color textPrimary;
  Color textSecondary;
  String cardShape;
  bool outlined;

  ModDraft({
    required this.name,
    required this.author,
    required this.dark,
    required this.background,
    required this.card,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardShape,
    required this.outlined,
  });

  /// Paleta completa a partir de un color de acento.
  factory ModDraft.fromAccent({
    required Color accent,
    required bool dark,
    String name = '',
    String author = '',
    String cardShape = 'rounded',
    bool outlined = true,
  }) {
    final double hue = HSLColor.fromColor(accent).hue;
    Color hsl(double s, double l) => HSLColor.fromAHSL(1, hue, s, l).toColor();
    return ModDraft(
      name: name,
      author: author,
      dark: dark,
      background: dark ? hsl(0.25, 0.08) : hsl(0.45, 0.96),
      card: dark ? hsl(0.22, 0.12) : hsl(0.50, 0.99),
      accent: accent,
      textPrimary: dark ? hsl(0.15, 0.94) : hsl(0.35, 0.16),
      textSecondary: dark ? hsl(0.12, 0.72) : hsl(0.25, 0.34),
      cardShape: cardShape,
      outlined: outlined,
    );
  }

  /// Borrador a partir de un mod ya existente (para editarlo o duplicarlo).
  factory ModDraft.fromModTheme(ModTheme m) {
    final bool dark = m.preferredBrightness == Brightness.dark;
    final ModDraft d = ModDraft.fromAccent(
      accent: m.accent ?? const Color(0xFF26C6A6),
      dark: dark,
      name: m.name,
      author: m.author ?? '',
      cardShape: kModShapes.contains(m.cardShape) ? m.cardShape! : 'rounded',
      outlined: m.cardStyle != 'filled',
    );
    if (m.background != null) d.background = m.background!;
    if (m.card != null) d.card = m.card!;
    if (m.textPrimary != null) d.textPrimary = m.textPrimary!;
    if (m.textSecondary != null) d.textSecondary = m.textSecondary!;
    return d;
  }

  /// Vuelve a generar fondo, tarjeta y textos desde el acento y el modo actuales.
  void regenerate() {
    final ModDraft fresh = ModDraft.fromAccent(accent: accent, dark: dark);
    background = fresh.background;
    card = fresh.card;
    textPrimary = fresh.textPrimary;
    textSecondary = fresh.textSecondary;
  }

  // Colores derivados (no se editan: se calculan siempre a partir de los demás).
  Color get cardAlt => Color.lerp(card, textPrimary, dark ? 0.08 : 0.06)!;
  Color get border => Color.lerp(card, accent, 0.45)!;
  Color get accentSecondary {
    final HSLColor h = HSLColor.fromColor(accent);
    return h.withHue((h.hue + 40) % 360).toColor();
  }

  double get cardRadius => _radiusForShape(cardShape);

  /// JSON en el mismo formato que los mods incluidos.
  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        if (author.trim().isNotEmpty) 'author': author.trim(),
        'description': 'Mod creado con el editor de la app.',
        'preferredBrightness': dark ? 'dark' : 'light',
        'colors': {
          'background': colorToHex(background),
          'card': colorToHex(card),
          'cardAlt': colorToHex(cardAlt),
          'accent': colorToHex(accent),
          'accentSecondary': colorToHex(accentSecondary),
          'textPrimary': colorToHex(textPrimary),
          'textSecondary': colorToHex(textSecondary),
          'border': colorToHex(border),
        },
        'style': {
          'cardRadius': cardRadius,
          'buttonRadius': 14,
          'cardShape': cardShape,
          'buttonShape': cardShape,
          'cardStyle': outlined ? 'outlined' : 'filled',
          'buttonStyle': 'filled',
          'borderWidth': 1.2,
          'elevation': 0,
          'density': 'comfortable',
          'cornerAccent': 'none',
        },
        'overlay': {'pattern': 'none', 'opacity': 0.05},
      };
}
