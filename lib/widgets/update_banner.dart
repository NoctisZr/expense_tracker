import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/locale_provider.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';
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
              child: Text(locale.t('upd_actualizar')),
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

/// Ventana de actualización: novedades y botón «Actualizar ahora». Descarga el
/// APK dentro de la app (con progreso), lo verifica y abre el instalador de
/// Android; solo falta que el usuario confirme.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  String _notes() {
    // Se quitan los encabezados y la sección de instalación del texto del release.
    String notes = info.notes;
    final int cut = notes.indexOf('### ');
    if (cut > 0) notes = notes.substring(0, cut);
    notes = notes.replaceAll(RegExp(r'^#+\s.*$', multiLine: true), '').replaceAll('---', '').trim();
    if (notes.length > 900) notes = '${notes.substring(0, 900)}…';
    return notes;
  }

  String _problemText(LocaleProvider l, UpdateProblem p) {
    switch (p) {
      case UpdateProblem.network:
        return l.t('upd_err_red');
      case UpdateProblem.invalid:
        return l.t('upd_err_archivo');
      case UpdateProblem.noApk:
        return l.t('upd_err_sin_apk');
      case UpdateProblem.permission:
        return l.t('upd_err_permiso');
      default:
        return l.t('upd_err_instalador');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final update = context.watch<UpdateProvider>();
    final theme = Theme.of(context);
    final UpdateInfo current = update.available ?? info;
    final String title = '${locale.t('actualizacion_titulo')} ${current.version}';
    final int? size = current.downloadSize;
    final String sizeText = size == null ? '' : '${(size / 1048576).toStringAsFixed(1)} MB';

    Widget body;
    List<Widget> actions;

    if (update.phase == UpdatePhase.downloading) {
      final int percent = (update.progress * 100).round();
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locale.t('upd_descargando')),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: update.progress > 0 ? update.progress : null,
            minHeight: 8,
            semanticsLabel: '${locale.t('upd_descargando')} $percent %',
          ),
          const SizedBox(height: 8),
          Text(
            update.progress > 0 ? '$percent %${sizeText.isEmpty ? '' : ' · $sizeText'}' : sizeText,
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
      actions = [TextButton(onPressed: update.cancelDownload, child: Text(locale.t('cancelar')))];
    } else if (update.phase == UpdatePhase.installing) {
      body = Row(
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 14),
          Expanded(child: Text(locale.t('upd_instalando'))),
        ],
      );
      actions = const [];
    } else if (update.installerOpened) {
      body = Text(locale.t('upd_confirmar'));
      actions = [
        TextButton(
          onPressed: () {
            update.clearProblem();
            Navigator.of(context).pop();
          },
          child: Text(locale.t('upd_cerrar')),
        ),
        ElevatedButton(onPressed: update.startUpdate, child: Text(locale.t('upd_otra_vez'))),
      ];
    } else if (update.problem != UpdateProblem.none) {
      body = Text(_problemText(locale, update.problem));
      actions = [
        TextButton(
          onPressed: () {
            update.clearProblem();
            Navigator.of(context).pop();
          },
          child: Text(locale.t('upd_cerrar')),
        ),
        ElevatedButton(onPressed: update.startUpdate, child: Text(locale.t('upd_reintentar'))),
      ];
    } else {
      final String notes = _notes();
      body = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notes.isEmpty ? locale.t('actualizacion_sin_notas') : notes),
            if (sizeText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${locale.t('upd_tamano')}: $sizeText', style: theme.textTheme.bodySmall),
            ],
            if (update.canInstallInApp) ...[
              const SizedBox(height: 10),
              Text(locale.t('upd_aviso'), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      );
      actions = [
        TextButton(
          onPressed: () {
            update.skip();
            Navigator.of(context).pop();
          },
          child: Text(locale.t('actualizacion_omitir')),
        ),
        TextButton(
          onPressed: () {
            update.dismissForSession();
            Navigator.of(context).pop();
          },
          child: Text(locale.t('actualizacion_mas_tarde')),
        ),
        ElevatedButton(
          onPressed: update.startUpdate,
          child: Text(update.canInstallInApp ? locale.t('upd_actualizar_ahora') : locale.t('actualizacion_descargar')),
        ),
      ];
    }

    return AlertDialog(
      title: Text(title),
      content: body,
      actions: actions,
    );
  }
}
