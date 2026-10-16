import 'package:flutter/material.dart';
import '../models/mod_theme.dart';

/// Relación de contraste WCAG entre dos colores (1 = igual, 21 = máximo).
double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Mínimo recomendado para el texto principal (WCAG AA).
const double kMinPrimaryContrast = 4.5;

/// Mínimo exigido al texto secundario (algo más laxo, es texto de apoyo).
const double kMinSecondaryContrast = 4.0;

/// Avisos de legibilidad de un mod: se comparan los colores de texto con
/// los fondos que el propio mod define. Cada aviso es una clave de
/// traducción: 'contraste_texto_principal' o 'contraste_texto_secundario'.
/// Si el mod no define el texto o el fondo, no se puede comparar y no se
/// avisa de nada.
List<String> modContrastWarnings(ModTheme mod) {
  final List<Color> backgrounds = [
    if (mod.background != null) mod.background!,
    if (mod.card != null) mod.card!,
  ];
  final List<String> warnings = [];

  final Color? primary = mod.textPrimary;
  if (primary != null && backgrounds.isNotEmpty) {
    final bool low = backgrounds.any((bg) => contrastRatio(primary, bg) < kMinPrimaryContrast);
    if (low) warnings.add('contraste_texto_principal');
  }

  final Color? secondary = mod.textSecondary;
  if (secondary != null && backgrounds.isNotEmpty) {
    final bool low = backgrounds.any((bg) => contrastRatio(secondary, bg) < kMinSecondaryContrast);
    if (low) warnings.add('contraste_texto_secundario');
  }
  return warnings;
}
