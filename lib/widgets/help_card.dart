import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/locale_provider.dart';
import '../providers/update_provider.dart';
import '../screens/feedback_screen.dart';
import 'section_card.dart';
import 'update_banner.dart';

/// Ajustes -> "Ayuda y novedades": versión, buscar actualizaciones y el botón
/// para reportar un fallo o sugerir una mejora.
class HelpCard extends StatelessWidget {
  const HelpCard({super.key});

  Future<void> _checkUpdates(BuildContext context) async {
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

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('ayuda_y_novedades')),
          const SizedBox(height: 4),
          Text('${locale.t('version')} $kAppVersion (build $kAppBuild)', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: update.isChecking ? null : () => _checkUpdates(context),
                icon: update.isChecking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.system_update_alt_rounded),
                label: Text(locale.t('actualizacion_buscar')),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                ),
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(locale.t('reportar_titulo')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
