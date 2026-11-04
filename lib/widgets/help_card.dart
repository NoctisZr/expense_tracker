import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_config.dart';
import '../providers/locale_provider.dart';
import '../screens/feedback_screen.dart';
import 'section_card.dart';

/// Ajustes -> "Ayuda y novedades": versión, buscar actualizaciones y el botón
/// para reportar un fallo o sugerir una mejora.
class HelpCard extends StatelessWidget {
  const HelpCard({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
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
