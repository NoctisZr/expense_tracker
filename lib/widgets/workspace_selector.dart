import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workspace.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';

/// Selector de espacio de trabajo (Personal, Negocio...). Cada espacio
/// tiene sus propios gastos, ingresos, bóvedas, presupuestos y recurrentes.
class WorkspaceSelector extends StatelessWidget {
  const WorkspaceSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final Workspace active = finance.activeWorkspace;

    return PopupMenuButton<String>(
      tooltip: locale.t('espacio_activo'),
      color: theme.colorScheme.surface,
      onSelected: (value) => _handleSelection(context, value),
      itemBuilder: (menuContext) => [
        for (final ws in finance.workspaces)
          PopupMenuItem<String>(
            value: 'ws:${ws.id}',
            child: Row(
              children: [
                Icon(
                  ws.id == active.id ? Icons.check_rounded : Icons.folder_open_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(ws.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'new',
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 18),
              const SizedBox(width: 10),
              Text(locale.t('nuevo_espacio')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 10),
              Text(locale.t('renombrar_espacio')),
            ],
          ),
        ),
        if (!finance.isPersonalWorkspace)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Text(
                  locale.t('eliminar_espacio'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspaces_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                active.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSelection(BuildContext context, String value) async {
    final finance = context.read<FinanceProvider>();
    final locale = context.read<LocaleProvider>();

    if (value.startsWith('ws:')) {
      await finance.switchWorkspace(value.substring(3));
    } else if (value == 'new') {
      final String? name = await _askName(context, locale, locale.t('nuevo_espacio'), '');
      if (name != null && name.isNotEmpty) await finance.createWorkspace(name);
    } else if (value == 'rename') {
      final String? name = await _askName(
        context,
        locale,
        locale.t('renombrar_espacio'),
        finance.activeWorkspace.name,
      );
      if (name != null && name.isNotEmpty) {
        await finance.renameWorkspace(finance.activeWorkspaceId, name);
      }
    } else if (value == 'delete') {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(locale.t('eliminar_espacio_titulo')),
          content: Text(locale.t('eliminar_espacio_mensaje')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(locale.t('cancelar')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(locale.t('eliminar')),
            ),
          ],
        ),
      );
      if (confirmed == true) await finance.deleteWorkspace(finance.activeWorkspaceId);
    }
  }

  Future<String?> _askName(
    BuildContext context,
    LocaleProvider locale,
    String title,
    String initial,
  ) {
    final TextEditingController controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: locale.t('nombre_espacio')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(locale.t('guardar')),
          ),
        ],
      ),
    );
  }
}
