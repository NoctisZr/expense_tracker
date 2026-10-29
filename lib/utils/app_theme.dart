import 'package:flutter/material.dart';
import '../models/mod_theme.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extension.dart';
import '../utils/mod_shapes.dart';

/// Construye el ThemeData completo de la app a partir del modo
/// oscuro/claro activo, el color de acento elegido por el usuario y,
/// opcionalmente, un [mod] de personalización cargado en Ajustes.
///
/// Cada valor del mod es opcional de forma independiente. Además de
/// colores, un mod puede pedir tarjetas/botones "outlined" en vez de
/// rellenos, una FORMA real distinta (esquinas biseladas tipo espada,
/// píldora, squircle — no solo un radio), acentos de esquina tipo HUD,
/// el grosor de borde, la sombra, la densidad general de la UI y una
/// "máscara" (patrón dibujado o imagen propia) encima de toda la app.
/// Todo esto es apariencia de superficie — nunca layout ni lógica.
ThemeData buildAppTheme({required bool isDark, required Color accent, ModTheme? mod}) {
  final Color effectiveAccent = mod?.accent ?? accent;
  final Color onAccent = AppColors.onColorFor(effectiveAccent);

  final Color defaultBackground = isDark ? AppColors.darkBackground : AppColors.lightBackground;
  final Color defaultCard = isDark ? AppColors.darkCard : AppColors.lightCard;
  final Color defaultCardAlt = isDark ? AppColors.darkCardAlt : const Color(0xFFE7E7EE);
  final Color defaultTextPrimary = isDark ? const Color(0xFFF1FAFF) : const Color(0xFF10283B);
  final Color defaultTextSecondary = isDark ? const Color(0xFF9BB4C5) : const Color(0xFF668092);
  final Color defaultBorder = isDark ? const Color(0xFF23445B) : const Color(0xFFD8E6E8);

  final Color effectiveBackground = mod?.background ?? defaultBackground;
  final Color effectiveCard = mod?.card ?? defaultCard;
  final Color effectiveCardAlt = mod?.cardAlt ?? defaultCardAlt;
  final Color effectiveAccentSecondary = mod?.accentSecondary ?? effectiveAccent;
  final Color effectiveTextPrimary = mod?.textPrimary ?? defaultTextPrimary;
  final Color effectiveTextSecondary = mod?.textSecondary ?? defaultTextSecondary;
  final Color effectiveWarning = mod?.warning ?? AppColors.warningRed;
  final Color effectiveExpense = mod?.expense ?? AppColors.expenseColor;
  final Color effectiveVault = mod?.vault ?? AppColors.vaultColor;
  final Color effectiveSuccess = mod?.success ?? AppColors.addFundColor;
  final Color effectiveDanger = mod?.danger ?? AppColors.removeFundColor;
  final Color effectiveBorder = mod?.border ?? defaultBorder;
  final double effectiveCardRadius = mod?.cardRadius ?? 18;
  final double effectiveButtonRadius = mod?.buttonRadius ?? 14;
  final double effectiveBorderWidth = mod?.borderWidth ?? 1.5;
  final double effectiveElevation = mod?.elevation ?? 0;
  final bool cardOutlined = mod?.cardStyle == 'outlined';
  final String buttonStyle = mod?.buttonStyle ?? 'filled';
  final String cardShapeKey = mod?.cardShape ?? 'rounded';
  final String buttonShapeKey = mod?.buttonShape ?? cardShapeKey;
  final bool cornerAccentEnabled = mod?.cornerAccent == 'brackets';
  final Color cornerAccentColor = mod?.cornerAccentColor ?? effectiveAccent;
  final String overlayPattern = mod?.overlayPattern ?? 'none';
  final double overlayOpacity = mod?.overlayOpacity ?? 0.06;

  final VisualDensity visualDensity = switch (mod?.density) {
    'compact' => VisualDensity.compact,
    'spacious' => const VisualDensity(horizontal: 1, vertical: 1),
    _ => VisualDensity.standard,
  };

  final ColorScheme colorScheme = ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    primary: effectiveAccent,
    onPrimary: onAccent,
    secondary: effectiveAccentSecondary,
    onSecondary: AppColors.onColorFor(effectiveAccentSecondary),
    surface: effectiveCard,
    onSurface: effectiveTextPrimary,
    error: effectiveWarning,
    onError: Colors.white,
    surfaceContainerHighest: effectiveCardAlt,
    outline: effectiveBorder,
  );

  final Color scaffoldBackground = effectiveBackground;
  final Color hintColor = effectiveTextSecondary;

  final Color cardFill = cardOutlined ? Colors.transparent : colorScheme.surface;
  final BorderSide cardBorderSide =
      cardOutlined ? BorderSide(color: effectiveBorder, width: effectiveBorderWidth) : BorderSide.none;

  late final Color btnBg;
  late final Color btnFg;
  late final BorderSide? btnSide;
  switch (buttonStyle) {
    case 'outlined':
      btnBg = Colors.transparent;
      btnFg = effectiveAccent;
      btnSide = BorderSide(color: effectiveAccent, width: effectiveBorderWidth);
      break;
    case 'text':
      btnBg = Colors.transparent;
      btnFg = effectiveAccent;
      btnSide = BorderSide.none;
      break;
    case 'filled':
    default:
      btnBg = effectiveAccent;
      btnFg = onAccent;
      btnSide = BorderSide.none;
  }

  final TextTheme baseTextTheme = ThemeData(
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    useMaterial3: true,
  ).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    visualDensity: visualDensity,
    scaffoldBackgroundColor: scaffoldBackground,
    canvasColor: scaffoldBackground,
    fontFamily: 'Roboto',
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackground,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    // Restaurado a CardThemeData
    cardTheme: CardThemeData(
      color: cardFill,
      elevation: effectiveElevation,
      margin: EdgeInsets.zero,
      shape: containerShapeBorderFor(cardShapeKey, effectiveCardRadius, side: cardBorderSide),
      clipBehavior: Clip.antiAlias,
    ),
    dividerColor: colorScheme.outline,
    hintColor: hintColor,
    textTheme: baseTextTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ).copyWith(
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: hintColor),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: hintColor),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: effectiveCardAlt.withValues(alpha: isDark ? 0.55 : 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: effectiveBorder.withValues(alpha: 0.65))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: effectiveAccent, width: 1.6)),
      labelStyle: TextStyle(color: hintColor),
      hintStyle: TextStyle(color: hintColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: btnBg,
        foregroundColor: btnFg,
        elevation: 0,
        side: btnSide,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        // Casteo explícito a OutlinedBorder
        shape: shapeBorderFor(buttonShapeKey, effectiveButtonRadius) as OutlinedBorder,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: effectiveAccent),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: effectiveAccent,
        side: BorderSide(color: effectiveAccent.withValues(alpha: 0.6), width: effectiveBorderWidth),
        // Casteo explícito a OutlinedBorder
        shape: shapeBorderFor(buttonShapeKey, effectiveButtonRadius) as OutlinedBorder,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: effectiveAccent,
      foregroundColor: onAccent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? effectiveAccent : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? effectiveAccent.withValues(alpha: 0.5)
            : null,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      selectedItemColor: effectiveAccent,
      unselectedItemColor: hintColor,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
      elevation: 0,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
    ),
    // Restaurado a DialogThemeData
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: containerShapeBorderFor(cardShapeKey, effectiveCardRadius + 2),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: colorScheme.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: effectiveAccent),
    extensions: [
      AppThemeExtras(
        cardAlt: effectiveCardAlt,
        accentSecondary: effectiveAccentSecondary,
        expense: effectiveExpense,
        vault: effectiveVault,
        success: effectiveSuccess,
        danger: effectiveDanger,
        border: effectiveBorder,
        cardRadius: effectiveCardRadius,
        buttonRadius: effectiveButtonRadius,
        borderWidth: effectiveBorderWidth,
        cardShapeKey: cardShapeKey,
        buttonShapeKey: buttonShapeKey,
        cornerAccentEnabled: cornerAccentEnabled,
        cornerAccentColor: cornerAccentColor,
        overlayPattern: overlayPattern,
        overlayOpacity: overlayOpacity,
        overlayImageBase64: mod?.overlayImageBase64,
      ),
    ],
  );
}
