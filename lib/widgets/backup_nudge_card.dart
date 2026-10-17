import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../services/backup_service.dart';
import 'section_card.dart';

/// Recordatorio amable: si pasaron más de 14 días desde tu última
/// exportación, sugiere guardar un respaldo en tu nube (los respaldos
/// automáticos viven dentro de la app y se pierden al desinstalarla).
class BackupNudgeCard extends StatefulWidget {
  const BackupNudgeCard({super.key});

  @override
  State<BackupNudgeCard> createState() => _BackupNudgeCardState();
}

class _BackupNudgeCardState extends State<BackupNudgeCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final bool hasData = finance.expensesBox.isNotEmpty ||
        finance.incomesBox.isNotEmpty ||
        finance.vaultsBox.isNotEmpty;
    if (!hasData) return const SizedBox.shrink();

    final settings = finance.settingsBox;
    final DateTime now = DateTime.now();
    final DateTime? snoozedUntil =
        DateTime.tryParse((settings.get(FinanceProvider.backupNudgeSnoozeKey) as String?) ?? '');
    if (snoozedUntil != null && snoozedUntil.isAfter(now)) return const SizedBox.shrink();

    final DateTime? lastExport =
        DateTime.tryParse((settings.get(FinanceProvider.lastExportKey) as String?) ?? '');
    final int? daysSince = lastExport == null ? null : now.difference(lastExport).inDays;
    if (daysSince != null && daysSince < 14) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    daysSince == null
                        ? locale.t('recordatorio_respaldo_nunca')
                        : '${locale.t('recordatorio_respaldo_hace')} $daysSince ${locale.t('dias')}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(locale.t('recordatorio_respaldo_texto'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await BackupService().exportAndShare(finance.exportData());
                      await settings.put(FinanceProvider.lastExportKey, DateTime.now().toIso8601String());
                      if (mounted) setState(() => _hidden = true);
                    } catch (_) {
                      messenger.showSnackBar(SnackBar(content: Text(locale.t('error_exportar'))));
                    }
                  },
                  child: Text(locale.t('exportar_ahora')),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () async {
                    await settings.put(
                      FinanceProvider.backupNudgeSnoozeKey,
                      now.add(const Duration(days: 7)).toIso8601String(),
                    );
                    if (mounted) setState(() => _hidden = true);
                  },
                  child: Text(locale.t('luego')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
