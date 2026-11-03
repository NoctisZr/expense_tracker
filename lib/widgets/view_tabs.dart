import 'package:flutter/material.dart';

class ViewTabItem {
  final int value;
  final IconData icon;
  final String label;

  /// Cantidad de novedades (0 = sin insignia).
  final int badge;
  const ViewTabItem({required this.value, required this.icon, required this.label, this.badge = 0});
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(item.icon, size: 22, color: item.value == selected ? primary : muted),
                            if (item.badge > 0)
                              Positioned(
                                right: -9,
                                top: -5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    item.badge > 9 ? '9+' : '${item.badge}',
                                    style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
