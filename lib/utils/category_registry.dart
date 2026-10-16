import 'package:flutter/material.dart';

/// Iconos y colores disponibles para categorías personalizadas. Se guardan
/// como ÍNDICES (no como código de icono) para que el build de release
/// pueda reducir las fuentes de iconos sin problemas.
const List<IconData> kCustomCategoryIcons = [
  Icons.pets_rounded,
  Icons.directions_car_rounded,
  Icons.home_rounded,
  Icons.school_rounded,
  Icons.favorite_rounded,
  Icons.flight_rounded,
  Icons.sports_esports_rounded,
  Icons.medical_services_rounded,
  Icons.card_giftcard_rounded,
  Icons.local_cafe_rounded,
  Icons.fitness_center_rounded,
  Icons.work_rounded,
];

const List<Color> kCustomCategoryColors = [
  Color(0xFFE57373),
  Color(0xFFBA68C8),
  Color(0xFF64B5F6),
  Color(0xFF4DB6AC),
  Color(0xFFFFD54F),
  Color(0xFFFF8A65),
  Color(0xFFA1887F),
  Color(0xFF90A4AE),
];

/// Categoría creada por el usuario. El nombre ES el identificador: se
/// guarda tal cual en cada gasto y, como AppStrings devuelve la propia
/// clave cuando no existe traducción, se muestra directamente.
class CustomCategory {
  final String name;
  final int iconIndex;
  final int colorIndex;

  const CustomCategory({
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
  });

  IconData get icon => kCustomCategoryIcons[iconIndex % kCustomCategoryIcons.length];
  Color get color => kCustomCategoryColors[colorIndex % kCustomCategoryColors.length];

  Map<String, dynamic> toMap() => {
        'name': name,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
      };

  factory CustomCategory.fromMap(Map<dynamic, dynamic> map) => CustomCategory(
        name: map['name'].toString(),
        iconIndex: (map['iconIndex'] as num).toInt(),
        colorIndex: (map['colorIndex'] as num).toInt(),
      );
}

/// Registro global (en memoria) de las categorías personalizadas. Lo
/// rellena FinanceProvider al arrancar y cada vez que cambian, así las
/// funciones de estilo de categoría siguen siendo simples y sin contexto.
class CategoryRegistry {
  static List<CustomCategory> _custom = const [];

  static List<CustomCategory> get custom => List.unmodifiable(_custom);

  static void load(List<CustomCategory> categories) {
    _custom = List<CustomCategory>.of(categories);
  }

  static CustomCategory? find(String name) {
    for (final c in _custom) {
      if (c.name == name) return c;
    }
    return null;
  }
}
