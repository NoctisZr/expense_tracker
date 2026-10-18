import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../models/mod_theme.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/mod_editor_screen.dart';
import '../utils/contrast_utils.dart';

/// Mods incluidos dentro de la app (carpeta `mods/`, declarada en assets).
const List<String> kBundledModAssets = [
  'mods/ejemplo_aurora.json',
  'mods/ejemplo_atardecer.json',
  'mods/madoka_kaname.json',
  'mods/yorha_nier_automata.json',
];

/// Aplica un mod revisando antes su legibilidad: si el texto tendría poco
/// contraste con los fondos del mod, se avisa y el usuario decide.
/// Con [saveToMyMods] el mod además queda guardado en "Mis mods".
/// Devuelve `true` si el mod quedó aplicado.
Future<bool> applyModWithChecks(
  BuildContext context,
  Map<String, dynamic> modJson, {
  bool saveToMyMods = false,
}) async {
  final ModTheme mod = ModTheme.fromJson(modJson);
  final List<String> warnings = modContrastWarnings(mod);

  if (warnings.isNotEmpty) {
    final locale = context.read<LocaleProvider>();
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('contraste_bajo_titulo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locale.t('contraste_bajo_mensaje')),
            const SizedBox(height: 10),
            for (final w in warnings) Text('• ${locale.t(w)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(locale.t('aplicar_igual')),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return false;
  }

  final theme = context.read<ThemeProvider>();
  theme.applyMod(mod, modJson);
  if (saveToMyMods) await theme.saveUserMod(modJson);
  return true;
}

Future<void> showModGallery(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ModGallerySheet(),
  );
}

/// Pide pegar el texto (JSON) de un mod, por ejemplo uno que te pasaron por
/// WhatsApp, y lo aplica y guarda en "Mis mods".
Future<void> showPasteModDialog(BuildContext context) async {
  final locale = context.read<LocaleProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final TextEditingController controller = TextEditingController();

  final String? text = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(locale.t('pegar_mod')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locale.t('pegar_mod_ayuda'), style: Theme.of(dialogContext).textTheme.bodySmall),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 8,
            minLines: 4,
            autocorrect: false,
            decoration: const InputDecoration(hintText: '{ "name": "...", "colors": { ... } }'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text(locale.t('aplicar')),
        ),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;

  try {
    final dynamic decoded = json.decode(text);
    if (decoded is! Map) throw const FormatException('no es un objeto');
    final applied =
        await applyModWithChecks(context, Map<String, dynamic>.from(decoded), saveToMyMods: true);
    if (applied) messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_aplicado_exitosamente'))));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_invalido'))));
  }
}

class _ModGallerySheet extends StatefulWidget {
  const _ModGallerySheet();

  @override
  State<_ModGallerySheet> createState() => _ModGallerySheetState();
}

class _ModGallerySheetState extends State<_ModGallerySheet> {
  late final Future<List<Map<String, dynamic>>> _bundled = _loadBundled();

  Future<List<Map<String, dynamic>>> _loadBundled() async {
    final List<Map<String, dynamic>> result = [];
    for (final String asset in kBundledModAssets) {
      try {
        final dynamic decoded = json.decode(await rootBundle.loadString(asset));
        if (decoded is Map) result.add(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // Un mod ilegible no debe romper la galería: se omite.
      }
    }
    return result;
  }

  Color? _color(Map<String, dynamic> mod, String key) {
    final dynamic colors = mod['colors'];
    if (colors is! Map) return null;
    final dynamic raw = colors[key];
    if (raw is! String) return null;
    final String hex = raw.replaceFirst('#', '');
    final int? value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? null : Color(value);
  }

  Future<void> _apply(Map<String, dynamic> mod) async {
    final locale = context.read<LocaleProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bool applied = await applyModWithChecks(context, mod);
      if (applied) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_aplicado_exitosamente'))));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_invalido'))));
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? initial, bool editing = false}) async {
    final navigator = Navigator.of(context);
    navigator.pop(); // cierra la galería; el editor ocupa toda la pantalla
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ModEditorScreen(initial: initial, editingExisting: editing),
      ),
    );
  }

  Widget _tile(Map<String, dynamic> mod, {required bool mine}) {
    final locale = context.read<LocaleProvider>();
    final theme = Theme.of(context);
    final List<Color?> swatches = [
      _color(mod, 'background'),
      _color(mod, 'card'),
      _color(mod, 'accent'),
      _color(mod, 'accentSecondary'),
      _color(mod, 'textPrimary'),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _apply(mod),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (mod['name'] ?? '').toString(),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (mod['author'] != null)
                    Text('${locale.t('mod_por')} ${mod['author']}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            for (final c in swatches)
              if (c != null)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                  ),
                ),
            PopupMenuButton<String>(
              color: theme.colorScheme.surface,
              onSelected: (value) async {
                final themeProvider = context.read<ThemeProvider>();
                if (value == 'edit') {
                  await _openEditor(initial: mod, editing: mine);
                } else if (value == 'share') {
                  await shareModJson(mod);
                } else if (value == 'delete') {
                  await themeProvider.deleteUserMod((mod['name'] as String));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Text(mine ? locale.t('editar') : locale.t('mod_duplicar_editar')),
                ),
                PopupMenuItem(value: 'share', child: Text(locale.t('mod_compartir'))),
                if (mine) PopupMenuItem(value: 'delete', child: Text(locale.t('eliminar'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> mine = context.watch<ThemeProvider>().userMods;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                locale.t('galeria_mods'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(locale.t('crear_mod')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      showPasteModDialog(navigator.context);
                    },
                    icon: const Icon(Icons.content_paste_rounded),
                    label: Text(locale.t('pegar_mod')),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(locale.t('mis_mods'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                Text(locale.t('sin_mis_mods'), style: theme.textTheme.bodySmall)
              else
                for (final mod in mine)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: _tile(mod, mine: true)),
              const SizedBox(height: 14),
              Text(locale.t('mods_incluidos'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _bundled,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<Map<String, dynamic>> mods = snapshot.data!;
                  if (mods.isEmpty) return Text(locale.t('mod_invalido'));
                  return Column(
                    children: [
                      for (final mod in mods)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: _tile(mod, mine: false)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
