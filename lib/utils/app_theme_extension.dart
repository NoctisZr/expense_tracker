import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Extiende ThemeData con los "design tokens" propios de la app: colores
/// semánticos (gasto, bóveda, éxito, peligro), un segundo acento, la
/// forma (radios, forma geométrica, grosor de borde) y los acentos de
/// esquina / máscara que puede pedir un mod. Se lee en cualquier widget
/// con `Theme.of(context).extension<AppThemeExtras>()`.
@immutable
class AppThemeExtras extends ThemeExtension<AppThemeExtras> {
  final Color cardAlt;
  final Color accentSecondary;
  final Color expense;
  final Color vault;
  final Color success;
  final Color danger;
  final Color border;
  final double cardRadius;
  final double buttonRadius;
  final double borderWidth;

  final String cardShapeKey;
  final String buttonShapeKey;

  final bool cornerAccentEnabled;
  final Color cornerAccentColor;

  final String overlayPattern;
  final double overlayOpacity;
  final String? overlayImageBase64;

  const AppThemeExtras({
    required this.cardAlt,
    required this.accentSecondary,
    required this.expense,
    required this.vault,
    required this.success,
    required this.danger,
    required this.border,
    required this.cardRadius,
    required this.buttonRadius,
    required this.borderWidth,
    required this.cardShapeKey,
    required this.buttonShapeKey,
    required this.cornerAccentEnabled,
    required this.cornerAccentColor,
    required this.overlayPattern,
    required this.overlayOpacity,
    required this.overlayImageBase64,
  });

  @override
  AppThemeExtras copyWith({
    Color? cardAlt,
    Color? accentSecondary,
    Color? expense,
    Color? vault,
    Color? success,
    Color? danger,
    Color? border,
    double? cardRadius,
    double? buttonRadius,
    double? borderWidth,
    String? cardShapeKey,
    String? buttonShapeKey,
    bool? cornerAccentEnabled,
    Color? cornerAccentColor,
    String? overlayPattern,
    double? overlayOpacity,
    String? overlayImageBase64,
  }) {
    return AppThemeExtras(
      cardAlt: cardAlt ?? this.cardAlt,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      expense: expense ?? this.expense,
      vault: vault ?? this.vault,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      border: border ?? this.border,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      cardShapeKey: cardShapeKey ?? this.cardShapeKey,
      buttonShapeKey: buttonShapeKey ?? this.buttonShapeKey,
      cornerAccentEnabled: cornerAccentEnabled ?? this.cornerAccentEnabled,
      cornerAccentColor: cornerAccentColor ?? this.cornerAccentColor,
      overlayPattern: overlayPattern ?? this.overlayPattern,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayImageBase64: overlayImageBase64 ?? this.overlayImageBase64,
    );
  }

  @override
  AppThemeExtras lerp(ThemeExtension<AppThemeExtras>? other, double t) {
    if (other is! AppThemeExtras) return this;
    return AppThemeExtras(
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t) ?? cardAlt,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t) ?? accentSecondary,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      vault: Color.lerp(vault, other.vault, t) ?? vault,
      success: Color.lerp(success, other.success, t) ?? success,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      border: Color.lerp(border, other.border, t) ?? border,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t) ?? cardRadius,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t) ?? buttonRadius,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t) ?? borderWidth,
      cardShapeKey: t < 0.5 ? cardShapeKey : other.cardShapeKey,
      buttonShapeKey: t < 0.5 ? buttonShapeKey : other.buttonShapeKey,
      cornerAccentEnabled: t < 0.5 ? cornerAccentEnabled : other.cornerAccentEnabled,
      cornerAccentColor: Color.lerp(cornerAccentColor, other.cornerAccentColor, t) ?? cornerAccentColor,
      overlayPattern: t < 0.5 ? overlayPattern : other.overlayPattern,
      overlayOpacity: lerpDouble(overlayOpacity, other.overlayOpacity, t) ?? overlayOpacity,
      overlayImageBase64: t < 0.5 ? overlayImageBase64 : other.overlayImageBase64,
    );
  }
}
