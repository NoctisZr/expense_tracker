import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_registry.dart';

/// Crea una categoría personalizada. Devuelve su nombre si se creó.
Future<String?> showAddCategoryDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _AddCategoryDialog(),
  );
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();
  int _iconIndex = 0;
  int _colorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String name = _nameController.text.trim();
    final bool ok = context
        .read<FinanceProvider>()
        .addCustomCategory(name, _iconIndex, _colorIndex);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('categoria_invalida'))),
      );
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final Color selectedColor = kCustomCategoryColors[_colorIndex];

    return AlertDialog(
      title: Text(locale.t('nueva_categoria')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 24,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < kCustomCategoryIcons.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _iconIndex = i),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: i == _iconIndex
                            ? selectedColor.withValues(alpha: 0.2)
                            : theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: i == _iconIndex ? selectedColor : Colors.transparent,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        kCustomCategoryIcons[i],
                        size: 20,
                        color: i == _iconIndex ? selectedColor : theme.hintColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (int i = 0; i < kCustomCategoryColors.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _colorIndex = i),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kCustomCategoryColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == _colorIndex ? theme.colorScheme.onSurface : Colors.transparent,
                          width: 2.4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
