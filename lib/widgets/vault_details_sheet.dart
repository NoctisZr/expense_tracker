import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vault.dart';
import '../models/vault_transaction.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/mod_shapes.dart';
import '../utils/savings_projection.dart';

Future<void> showVaultDetailsSheet(BuildContext context, {required Vault vault}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VaultDetailsSheet(vault: vault),
  );
}

class _VaultDetailsSheet extends StatelessWidget {
  final Vault vault;
  const _VaultDetailsSheet({required this.vault});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<VaultTransaction> transactions = finance.transactionsForVault(vault.id);
    final SavingsProjection projection = calculateSavingsProjection(
      transactions: transactions,
      currentAmount: vault.currentAmount,
      targetAmount: vault.targetAmount,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: theme.hintColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        vault.name,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(locale.t('cerrar')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProjectionSection(vault: vault, projection: projection, locale: locale),
                const SizedBox(height: 26),
                Text(
                  locale.t('historial_aportes'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(locale.t('sin_movimientos'), style: TextStyle(color: theme.hintColor)),
                  )
                else
                  ...transactions.map(
                    (t) => _TransactionTile(transaction: t, vaultCurrency: vault.currency, locale: locale),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProjectionSection extends StatelessWidget {
  final Vault vault;
  final SavingsProjection projection;
  final LocaleProvider locale;

  const _ProjectionSection({required this.vault, required this.projection, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final extras = theme.extension<AppThemeExtras>()!;

    if (projection.goalReached) {
      return _infoBox(
        context,
        color: extras.success,
        icon: Icons.celebration_rounded,
        child: Text(
          locale.t('meta_alcanzada'),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
    }

    if (!projection.hasEnoughData) {
      return _infoBox(
        context,
        color: theme.hintColor,
        icon: Icons.insights_outlined,
        child: Text(
          locale.t('datos_insuficientes_proyeccion'),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return _infoBox(
      context,
      color: accent,
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            locale.t('proyeccion_ahorro'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _kv(theme, locale.t('ritmo_promedio'),
              '${formatCurrency(projection.avgPerDay, vault.currency)} ${locale.t('por_dia')}'),
          const SizedBox(height: 6),
          _kv(
            theme,
            locale.t('tiempo_estimado'),
            '${locale.t('aproximadamente')} '
            '${formatDaysApprox(projection.estimatedDaysRemaining, locale.t('dias'), locale.t('meses'))}',
          ),
          if (projection.estimatedCompletionDate != null) ...[
            const SizedBox(height: 6),
            _kv(theme, locale.t('fecha_estimada'), formatDateShort(projection.estimatedCompletionDate!)),
          ],
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _infoBox(BuildContext context, {required Color color, required IconData icon, required Widget child}) {
    final extras = Theme.of(context).extension<AppThemeExtras>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: borderRadiusApproxFor(extras.cardShapeKey, extras.cardRadius - 2),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final VaultTransaction transaction;
  final String vaultCurrency;
  final LocaleProvider locale;

  const _TransactionTile({
    required this.transaction,
    required this.vaultCurrency,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;
    final Color color = transaction.isWithdrawal ? extras.danger : extras.success;
    final bool wasConverted = transaction.currency != vaultCurrency;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(
              transaction.isWithdrawal ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.isWithdrawal ? locale.t('retiro') : locale.t('aporte'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(formatDateShort(transaction.date), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(transaction.amount, transaction.currency),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              if (wasConverted)
                Text(
                  '≈ ${formatCurrency(transaction.convertedAmount, vaultCurrency)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
