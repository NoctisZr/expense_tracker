import 'package:flutter/material.dart';
import '../models/expense.dart';
import 'category_registry.dart';

IconData categoryIcon(String category) {
  final CustomCategory? custom = CategoryRegistry.find(category);
  if (custom != null) return custom.icon;
  switch (category) {
    case ExpenseCategory.compras:
      return Icons.shopping_bag_rounded;
    case ExpenseCategory.servicios:
      return Icons.bolt_rounded;
    case ExpenseCategory.comida:
      return Icons.restaurant_rounded;
    case ExpenseCategory.otros:
    default:
      return Icons.category_rounded;
  }
}

Color categoryColor(String category) {
  final CustomCategory? custom = CategoryRegistry.find(category);
  if (custom != null) return custom.color;
  switch (category) {
    case ExpenseCategory.compras:
      return const Color(0xFF4FC3D9);
    case ExpenseCategory.servicios:
      return const Color(0xFFF08A4B);
    case ExpenseCategory.comida:
      return const Color(0xFF7ED879);
    case ExpenseCategory.otros:
    default:
      return const Color(0xFF9E9EB3);
  }
}

String categoryLabelKey(String category) {
  // Las categorías personalizadas no tienen traducción: AppStrings devuelve
  // la propia clave (el nombre) cuando no existe, así que se muestra tal cual.
  if (CategoryRegistry.find(category) != null) return category;
  switch (category) {
    case ExpenseCategory.compras:
      return 'categoria_compras';
    case ExpenseCategory.servicios:
      return 'categoria_servicios';
    case ExpenseCategory.comida:
      return 'categoria_comida';
    case ExpenseCategory.otros:
    default:
      return 'categoria_otros';
  }
}
