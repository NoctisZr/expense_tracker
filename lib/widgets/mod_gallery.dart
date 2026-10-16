import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../models/mod_theme.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
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
/// Devuelve `true` si el mod quedó aplicado.
Future<bool> applyModWithChecks(BuildContext context, Map<String, dynamic> modJson) async {
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

  context.read<ThemeProvider>().applyMod(mod, modJson);
  return true;
}

Future<void> showModGallery(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ModGallerySheet(),
  );
}

class _ModGallerySheet extends StatefulWidget {
  const _ModGallerySheet();

  @override
  State<_ModGallerySheet> createState() => _ModGallerySheetState();
}

class _ModGallerySheetState extends State<_ModGallerySheet> {
  late final Future<List<Map<String, dynamic>>> _mods = _load();

  Future<List<Map<String, dynamic>>> _load() async {
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

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.t('galeria_mods'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _mods,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<Map<String, dynamic>> mods = snapshot.data!;
                  if (mods.isEmpty) return Text(locale.t('mod_invalido'));
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: mods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> mod = mods[index];
                      final List<Color?> swatches = [
                        _color(mod, 'background'),
                        _color(mod, 'card'),
                        _color(mod, 'accent'),
                        _color(mod, 'accentSecondary'),
                        _color(mod, 'textPrimary'),
                      ];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final bool applied = await applyModWithChecks(context, mod);
                            if (applied) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(locale.t('mod_aplicado_exitosamente'))),
                              );
                            }
                          } catch (_) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(locale.t('mod_invalido'))),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
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
                                      Text(
                                        '${locale.t('mod_por')} ${mod['author']}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              for (final c in swatches)
                                if (c != null)
                                  Container(
                                    width: 22,
                                    height: 22,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
