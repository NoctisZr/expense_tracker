import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';

/// Fila con las 4 categorías fijas de gasto como chips seleccionables.
class CategorySelectorRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final LocaleProvider locale;

  const CategorySelectorRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.all.map((cat) {
        final bool isSelected = cat == selected;
        final Color color = categoryColor(cat);
        return CategoryChip(
          icon: categoryIcon(cat),
          label: locale.t(categoryLabelKey(cat)),
          selected: isSelected,
          color: color,
          onTap: () => onChanged(cat),
        );
      }).toList(),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? color.withValues(alpha: 0.2)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: selected ? color : theme.hintColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? color : theme.hintColor,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
