import 'package:flutter/material.dart';

class ViewTabItem {
  final int value;
  final IconData icon;
  final String label;
  const ViewTabItem({required this.value, required this.icon, required this.label});
}

/// Pestañas grandes y claras (icono arriba, una palabra abajo) para cambiar
/// de vista. Siempre caben en una línea: el texto se reduce en lugar de cortarse.
class ViewTabs extends StatelessWidget {
  final List<ViewTabItem> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const ViewTabs({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primary = theme.colorScheme.primary;
    final Color muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: item.value == selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(item.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                    decoration: BoxDecoration(
                      color: item.value == selected ? primary.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 22, color: item.value == selected ? primary : muted),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: item.value == selected ? FontWeight.bold : FontWeight.w500,
                              color: item.value == selected ? primary : muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
