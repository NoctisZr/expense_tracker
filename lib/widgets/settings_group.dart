import 'package:flutter/material.dart';

/// Grupo de ajustes que se abre y se cierra: mantiene Ajustes ordenado y deja
/// lo técnico escondido hasta que se necesita.
class SettingsGroup extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool initiallyExpanded;
  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          childrenPadding: const EdgeInsets.only(top: 6, bottom: 8),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: theme.textTheme.bodySmall),
          children: children,
        ),
      ),
    );
  }
}
