import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/locale_provider.dart';
import '../providers/update_provider.dart';
import '../services/update_service.dart';
import '../utils/formatters.dart';
import 'section_card.dart';
import 'update_banner.dart';

/// Primera tarjeta de Ajustes: versión instalada y el botón para actualizar,
/// siempre a la vista. Si hay una versión nueva, el botón la instala desde
/// la propia app.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  Future<void> _check(BuildContext context) async {
    final update = context.read<UpdateProvider>();
    final locale = context.read<LocaleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final UpdateCheckResult result = await update.check(manual: true);
    switch (result) {
      case UpdateCheckResult.available:
        if (update.available != null && context.mounted) await showUpdateDialog(context, update.available!);
        break;
      case UpdateCheckResult.upToDate:
        messenger.showSnackBar(SnackBar(content: Text(locale.t('actualizacion_al_dia'))));
        break;
      case UpdateCheckResult.failed:
        messenger.showSnackBar(SnackBar(content: Text(locale.t('actualizacion_error'))));
        break;
      case UpdateCheckResult.disabled:
        messenger.showSnackBar(SnackBar(content: Text(locale.t('actualizacion_no_configurada'))));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final update = context.watch<UpdateProvider>();
    final theme = Theme.of(context);
    final UpdateInfo? info = update.available;
    final bool has = update.hasUpdate && info != null;
    final DateTime? last = update.lastCheck;
    String lastText = '';
    if (last != null) {
      final String hh = last.hour.toString().padLeft(2, '0');
      final String mm = last.minute.toString().padLeft(2, '0');
      lastText = '${locale.t('upd_ultima')}: ${formatDateShort(last)} $hh:$mm';
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.16),
                child: Icon(Icons.system_update_alt_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(locale.t('upd_titulo'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${locale.t('version')} $kAppVersion (build $kAppBuild)', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (has) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${locale.t('actualizacion_disponible')} ${info.version}',
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: update.phase == UpdatePhase.idle ? () => showUpdateDialog(context, info) : null,
                icon: const Icon(Icons.download_rounded),
                label: Text('${locale.t('upd_actualizar_a')} ${info.version}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ] else ...[
            if (last != null) Text('${locale.t('upd_al_dia')}\n$lastText', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: update.isChecking ? null : () => _check(context),
                icon: update.isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                label: Text(locale.t('actualizacion_buscar')),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
