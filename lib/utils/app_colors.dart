import 'package:flutter/material.dart';

/// Paleta central de la aplicación. Mantener todos los colores aquí evita
/// valores hexadecimales sueltos repetidos por las pantallas y widgets.
class AppColors {
  AppColors._();

  static const Color darkBackground = Color(0xFF1A1A24);
  static const Color darkCard = Color(0xFF252530);
  static const Color darkCardAlt = Color(0xFF2E2E3A);

  static const Color lightBackground = Color(0xFFF2F2F6);
  static const Color lightCard = Color(0xFFFFFFFF);

  static const Color defaultAccent = Color(0xFF2DD4BF);

  static const Color warningRed = Color(0xFFEF6B6B);

  static const Color expenseColor = Color(0xFFF4A93B);
  static const Color vaultColor = Color(0xFF5C9DED);
  static const Color neutralGray = Color(0xFF8892A6);

  static const Color addFundColor = Color(0xFF4CAF6D);
  static const Color removeFundColor = Color(0xFFE05B5B);

  static const List<Color> themeOptions = [
    defaultAccent,
    Color(0xFF4A9BF0),
    Color(0xFF7ED879),
    Color(0xFFB073E0),
    Color(0xFFF08A4B),
    Color(0xFFF06BA8),
  ];

  static Color onColorFor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
