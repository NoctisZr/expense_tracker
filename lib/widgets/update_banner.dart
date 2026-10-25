import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/locale_provider.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';
import '../services/url_service.dart';
import 'section_card.dart';

/// Aviso de "nueva versión disponible" (arriba del Resumen). No se dibuja si
/// no hay versión nueva, o si el usuario la pospuso u omitió.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final UpdateInfo? info = update.available;
    if (!update.showBanner || info == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SectionCard(
        child: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${locale.t('actualizacion_disponible')} ${info.version}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text('${locale.t('actualizacion_tienes')} $kAppVersion', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showUpdateDialog(context, info),
              child: Text(locale.t('actualizacion_ver')),
            ),
            IconButton(
              onPressed: () => update.snooze(),
              icon: Icon(Icons.close, size: 18, color: theme.hintColor),
              tooltip: locale.t('actualizacion_mas_tarde'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Novedades de la versión nueva y botón de descarga.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  final locale = context.read<LocaleProvider>();
  final update = context.read<UpdateProvider>();
  final messenger = ScaffoldMessenger.of(context);

  // Se quitan los encabezados y la sección de instalación del texto del release.
  String notes = info.notes;
  final int cut = notes.indexOf('### ');
  if (cut > 0) notes = notes.substring(0, cut);
  notes = notes.replaceAll(RegExp(r'^#+\s.*$', multiLine: true), '').replaceAll('---', '').trim();
  if (notes.length > 900) notes = '${notes.substring(0, 900)}…';

  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${locale.t('actualizacion_titulo')} ${info.version}'),
      content: SingleChildScrollView(
        child: Text(notes.isEmpty ? locale.t('actualizacion_sin_notas') : notes),
      ),
      actions: [
        TextButton(
          onPressed: () {
            update.skip();
            Navigator.of(dialogContext).pop();
          },
          child: Text(locale.t('actualizacion_omitir')),
        ),
        TextButton(
          onPressed: () {
            update.snooze();
            Navigator.of(dialogContext).pop();
          },
          child: Text(locale.t('actualizacion_mas_tarde')),
        ),
        ElevatedButton(
          onPressed: () async {
            final String url = info.downloadUrl ?? info.pageUrl;
            Navigator.of(dialogContext).pop();
            final bool opened = await UrlService().open(url);
            if (!opened) {
              await Clipboard.setData(ClipboardData(text: url));
              messenger.showSnackBar(SnackBar(content: Text(locale.t('actualizacion_enlace_copiado'))));
            }
          },
          child: Text(locale.t('actualizacion_descargar')),
        ),
      ],
    ),
  );
}
