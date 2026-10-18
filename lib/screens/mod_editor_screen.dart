import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mod_theme.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_colors.dart';
import '../utils/contrast_utils.dart';
import '../utils/mod_builder.dart';
import '../utils/mod_shapes.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/section_card.dart';

/// Comparte el JSON de un mod como archivo (para pasárselo a otra persona).
Future<void> shareModJson(Map<String, dynamic> modJson) async {
  final Directory temp = await getTemporaryDirectory();
  final String safeName =
      (modJson['name'] as String).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final File file = File('${temp.path}/mod_$safeName.json');
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(modJson));
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')]);
}

/// Editor visual de mods: se elige un color y se genera toda la paleta;
/// después se ajusta lo que se quiera. Se guarda en "Mis mods".
class ModEditorScreen extends StatefulWidget {
  /// Mod existente para editar o duplicar (`null` = mod nuevo).
  final Map<String, dynamic>? initial;

  /// Si `true`, al guardar se reemplaza el mod original (mismo nombre).
  final bool editingExisting;

  const ModEditorScreen({super.key, this.initial, this.editingExisting = false});

  @override
  State<ModEditorScreen> createState() => _ModEditorScreenState();
}

class _ModEditorScreenState extends State<ModEditorScreen> {
  late ModDraft _draft;
  late final TextEditingController _nameController;
  late final TextEditingController _authorController;
  late final String? _originalName;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _draft = ModDraft.fromModTheme(ModTheme.fromJson(widget.initial!));
      _originalName = widget.editingExisting ? _draft.name : null;
    } else {
      _draft = ModDraft.fromAccent(accent: const Color(0xFFFF8FB3), dark: false);
      _originalName = null;
    }
    _nameController = TextEditingController(text: _draft.name);
    _authorController = TextEditingController(text: _draft.author);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pick(String title, Color current, ValueChanged<Color> onPicked, {bool regenerate = false}) async {
    final Color? color = await showColorPickerDialog(context, initial: current, title: title);
    if (color == null) return;
    setState(() {
      onPicked(color);
      if (regenerate) _draft.regenerate();
    });
  }

  Map<String, dynamic>? _validJson(LocaleProvider locale) {
    _draft.name = _nameController.text;
    _draft.author = _authorController.text;
    if (_draft.name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('mod_nombre_requerido'))),
      );
      return null;
    }
    return _draft.toJson();
  }

  Future<void> _saveAndApply() async {
    final locale = context.read<LocaleProvider>();
    final theme = context.read<ThemeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final Map<String, dynamic>? json = _validJson(locale);
    if (json == null) return;

    if (_originalName != null && _originalName != (json['name'] as String)) {
      await theme.deleteUserMod(_originalName);
    }
    await theme.saveUserMod(json);
    theme.applyMod(ModTheme.fromJson(json), json);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_guardado'))));
  }

  Future<void> _share() async {
    final locale = context.read<LocaleProvider>();
    final Map<String, dynamic>? json = _validJson(locale);
    if (json == null) return;
    await shareModJson(json);
  }

  Future<void> _copy() async {
    final locale = context.read<LocaleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final Map<String, dynamic>? json = _validJson(locale);
    if (json == null) return;
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)));
    messenger.showSnackBar(SnackBar(content: Text(locale.t('mod_json_copiado'))));
  }

  Widget _colorRow(String label, Color color, ValueChanged<Color> onPicked) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outline),
        ),
      ),
      title: Text(label),
      subtitle: Text(colorToHex(color), style: theme.textTheme.bodySmall),
      onTap: () => _pick(label, color, onPicked),
    );
  }

  String _shapeLabel(LocaleProvider locale, String shape) {
    switch (shape) {
      case 'stadium':
        return locale.t('mod_forma_pildora');
      case 'beveled':
        return locale.t('mod_forma_biselada');
      case 'continuous':
        return locale.t('mod_forma_suave');
      case 'rounded':
      default:
        return locale.t('mod_forma_redondeada');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final ModDraft d = _draft;
    // Aviso de legibilidad en vivo (mismo cálculo que al cargar un mod).
    final List<String> warnings = modContrastWarnings(ModTheme.fromJson(
      {...d.toJson(), 'name': d.name.trim().isEmpty ? 'preview' : d.name.trim()},
    ));

    final BorderSide previewBorder =
        d.outlined ? BorderSide(color: d.border, width: 1.2) : BorderSide.none;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null || !widget.editingExisting
            ? locale.t('crear_mod')
            : locale.t('editar_mod')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: locale.t('mod_nombre')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _authorController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: locale.t('mod_autor')),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(locale.t('mod_desde_color')),
                const SizedBox(height: 4),
                Text(locale.t('mod_desde_color_ayuda'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: true, label: Text(locale.t('mod_oscuro'), style: const TextStyle(fontSize: 12))),
                          ButtonSegment(value: false, label: Text(locale.t('mod_claro'), style: const TextStyle(fontSize: 12))),
                        ],
                        selected: {d.dark},
                        onSelectionChanged: (selection) => setState(() {
                          d.dark = selection.first;
                          d.regenerate();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _pick(
                        locale.t('mod_color_acento'),
                        d.accent,
                        (c) => d.accent = c,
                        regenerate: true,
                      ),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: d.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.outline, width: 2),
                        ),
                        child: Icon(Icons.colorize_rounded, size: 20, color: AppColors.onColorFor(d.accent)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(locale.t('mod_ajustar_colores')),
                _colorRow(locale.t('mod_color_fondo'), d.background, (c) => d.background = c),
                _colorRow(locale.t('mod_color_tarjeta'), d.card, (c) => d.card = c),
                _colorRow(locale.t('mod_color_acento'), d.accent, (c) => d.accent = c),
                _colorRow(locale.t('mod_color_texto'), d.textPrimary, (c) => d.textPrimary = c),
                _colorRow(locale.t('mod_color_texto_secundario'), d.textSecondary, (c) => d.textSecondary = c),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(locale.t('mod_forma_tarjetas')),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final shape in kModShapes)
                      ChoiceChip(
                        label: Text(_shapeLabel(locale, shape), style: const TextStyle(fontSize: 12)),
                        selected: d.cardShape == shape,
                        onSelected: (_) => setState(() => d.cardShape = shape),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(locale.t('mod_tarjetas_borde')),
                  value: d.outlined,
                  onChanged: (value) => setState(() => d.outlined = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionLabel(locale.t('mod_vista_previa')),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: d.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: ShapeDecoration(
                color: d.card,
                shape: containerShapeBorderFor(d.cardShape, d.cardRadius, side: previewBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale.t('mod_vista_previa_titulo'),
                    style: TextStyle(color: d.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.t('mod_vista_previa_texto'),
                    style: TextStyle(color: d.textSecondary, fontSize: 13.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: ShapeDecoration(
                          color: d.accent,
                          shape: shapeBorderFor(d.cardShape, 14),
                        ),
                        child: Text(
                          locale.t('guardar'),
                          style: TextStyle(color: AppColors.onColorFor(d.accent), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: ShapeDecoration(
                          color: d.cardAlt,
                          shape: shapeBorderFor(d.cardShape, 14),
                        ),
                        child: Text(locale.t('mod_vista_previa_chip'), style: TextStyle(color: d.textPrimary, fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (warnings.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(locale.t('mod_contraste_ok'), style: theme.textTheme.bodySmall)),
              ],
            )
          else
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(locale.t(w), style: TextStyle(color: theme.colorScheme.error, fontSize: 13))),
                  ],
                ),
              ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _saveAndApply,
            icon: const Icon(Icons.check_rounded),
            label: Text(locale.t('mod_guardar_aplicar')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(locale.t('mod_compartir')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(locale.t('mod_copiar_json')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
