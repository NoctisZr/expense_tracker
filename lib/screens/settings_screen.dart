import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/mod_theme.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/background_image_service.dart';
import '../services/backup_service.dart';
import '../utils/app_colors.dart';
import '../widgets/section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backupService = BackupService();
  final BackgroundImageService _backgroundService = BackgroundImageService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isProcessingImage = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleExport() async {
    final locale = context.read<LocaleProvider>();
    final data = context.read<FinanceProvider>().exportData();
    try {
      await _backupService.exportAndShare(data);
    } catch (_) {
      _showSnack(locale.t('error_exportar'));
    }
  }

  Future<void> _handleExportCsv() async {
    final locale = context.read<LocaleProvider>();
    final String csv = context.read<FinanceProvider>().exportExpensesCsv();
    try {
      await _backupService.exportCsvAndShare(csv);
    } catch (_) {
      _showSnack(locale.t('error_exportar'));
    }
  }

  Future<void> _handleImport() async {
    final locale = context.read<LocaleProvider>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('importar_confirmacion_titulo')),
        content: Text(locale.t('importar_confirmacion_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(locale.t('confirmar')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final Map<String, dynamic>? data = await _backupService.pickAndParseBackup();
      if (data == null || !mounted) return;
      await context.read<FinanceProvider>().importData(data);
      _showSnack(locale.t('importacion_exitosa'));
    } on BackupImportException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack(locale.t('error_importar'));
    }
  }

  Future<void> _handleLoadMod() async {
    final locale = context.read<LocaleProvider>();
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final String? path = result?.files.single.path;
    if (path == null || !mounted) return;

    try {
      final String content = await File(path).readAsString();
      final dynamic decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('formato inválido');
      }
      final Map<String, dynamic> modJson = decoded;
      final ModTheme mod = ModTheme.fromJson(modJson);
      if (!mounted) return;
      context.read<ThemeProvider>().applyMod(mod, modJson);
      _showSnack(locale.t('mod_aplicado_exitosamente'));
    } catch (_) {
      _showSnack(locale.t('mod_invalido'));
    }
  }

  Future<void> _handlePickBackground() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;

    setState(() => _isProcessingImage = true);
    final locale = context.read<LocaleProvider>();
    try {
      final rawBytes = await picked.readAsBytes();
      final String path = await _backgroundService.processAndSave(rawBytes);
      if (!mounted) return;
      context.read<ThemeProvider>().setBackgroundImagePath(path);
    } catch (_) {
      _showSnack(locale.t('archivo_invalido'));
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  Future<void> _handleRemoveBackground() async {
    final themeProvider = context.read<ThemeProvider>();
    final String? path = themeProvider.backgroundImagePath;
    themeProvider.setBackgroundImagePath(null);
    if (path != null) {
      await _backgroundService.deleteBackgroundFile(path);
    }
  }

  Future<void> _handleRemoveMod() async {
    context.read<ThemeProvider>().removeMod();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              locale.t('ajustes'),
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(locale.t('idioma'), style: theme.textTheme.titleMedium),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: locale.languageCode,
                      dropdownColor: theme.colorScheme.surface,
                      items: [
                        DropdownMenuItem(value: 'es', child: Text(locale.t('espanol'))),
                        DropdownMenuItem(value: 'en', child: Text(locale.t('ingles'))),
                        DropdownMenuItem(value: 'pt', child: Text(locale.t('portugues'))),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<LocaleProvider>().setLanguage(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(locale.t('modo_oscuro'), style: theme.textTheme.titleMedium),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => context.read<ThemeProvider>().toggleDarkMode(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('color_del_tema')),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: AppColors.themeOptions.map((color) {
                      final bool selected = themeProvider.activeMod == null &&
                          color.toARGB32() == themeProvider.accentColor.toARGB32();
                      return GestureDetector(
                        onTap: () => context.read<ThemeProvider>().setAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: selected ? 10 : 0,
                                spreadRadius: selected ? 1 : 0,
                              ),
                            ],
                          ),
                          child: selected
                              ? Icon(Icons.check, color: AppColors.onColorFor(color))
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('respaldo_y_datos')),
                  const SizedBox(height: 6),
                  Text(locale.t('exportar_descripcion'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _handleExport,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(locale.t('exportar_datos')),
                  ),
                  const SizedBox(height: 12),
                  Text(locale.t('exportar_csv_descripcion'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _handleExportCsv,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: Text(locale.t('exportar_csv')),
                  ),
                  const SizedBox(height: 16),
                  Text(locale.t('importar_descripcion'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _handleImport,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(locale.t('importar_datos')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('personalizacion_avanzada')),
                  const SizedBox(height: 6),
                  Text(locale.t('mods_descripcion'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${locale.t('mod_activo')}: ', style: theme.textTheme.bodySmall),
                      Expanded(
                        child: Text(
                          themeProvider.activeMod?.name ?? locale.t('ningun_mod_activo'),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (themeProvider.activeMod?.author != null &&
                      themeProvider.activeMod!.author!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${locale.t('mod_por')} ${themeProvider.activeMod!.author}',
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (themeProvider.activeMod?.description != null &&
                      themeProvider.activeMod!.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      themeProvider.activeMod!.description!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _handleLoadMod,
                        icon: const Icon(Icons.extension_rounded),
                        label: Text(locale.t('cargar_mod')),
                      ),
                      if (themeProvider.activeMod != null)
                        TextButton.icon(
                          onPressed: _handleRemoveMod,
                          icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error),
                          label: Text(locale.t('quitar_mod'), style: TextStyle(color: theme.colorScheme.error)),
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
                  SectionLabel(locale.t('fondo_personalizado')),
                  const SizedBox(height: 6),
                  Text(locale.t('fondo_descripcion'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  if (_isProcessingImage)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Text(locale.t('procesando_imagen'), style: theme.textTheme.bodySmall),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _handlePickBackground,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(locale.t('elegir_imagen_fondo')),
                        ),
                        if (themeProvider.backgroundImagePath != null)
                          TextButton.icon(
                            onPressed: _handleRemoveBackground,
                            icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error),
                            label: Text(locale.t('quitar_fondo'), style: TextStyle(color: theme.colorScheme.error)),
                          ),
                      ],
                    ),
                  if (themeProvider.backgroundImagePath != null && !_isProcessingImage) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(themeProvider.backgroundImagePath!),
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
