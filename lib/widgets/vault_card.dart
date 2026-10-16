import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vault.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/mod_shapes.dart';
import 'corner_accents.dart';

/// Tarjeta de una bóveda individual. El monto siempre se muestra en
/// `vault.currency`, nunca en la moneda local global.
class VaultCard extends StatelessWidget {
  final Vault vault;
  final String deLabel;
  final String verDetallesLabel;
  final VoidCallback onDelete;
  final VoidCallback onAddFunds;
  final VoidCallback onWithdrawFunds;
  final VoidCallback onViewDetails;

  const VaultCard({
    super.key,
    required this.vault,
    required this.deLabel,
    required this.verDetallesLabel,
    required this.onDelete,
    required this.onAddFunds,
    required this.onWithdrawFunds,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final extras = theme.extension<AppThemeExtras>()!;
    final currencyProvider = context.watch<CurrencyProvider>();
    final String localCurrency = context.watch<FinanceProvider>().localCurrency;
    final bool showLocalEquivalent = vault.currency != localCurrency &&
        currencyProvider.canConvert(vault.currency, localCurrency);
    final double localEquivalent = showLocalEquivalent
        ? currencyProvider.convert(vault.currentAmount, vault.currency, localCurrency)
        : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CornerAccents(
        enabled: extras.cornerAccentEnabled,
        color: extras.cornerAccentColor,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: shapeBorderFor(extras.cardShapeKey, extras.cardRadius - 2),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vault.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onViewDetails,
                  icon: Icon(Icons.insights_rounded, color: theme.hintColor),
                  tooltip: verDetallesLabel,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: vault.progress.toDouble(),
                minHeight: 8,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatPercent(vault.progressPercent)} $deLabel '
              '${formatCurrency(vault.targetAmount, vault.currency)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatCurrency(vault.currentAmount, vault.currency),
                          maxLines: 1,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (showLocalEquivalent)
                        Text(
                          '≈ ${formatCurrency(localEquivalent, localCurrency)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.remove,
                  color: extras.danger,
                  onTap: onWithdrawFunds,
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.add,
                  color: extras.success,
                  onTap: onAddFunds,
                ),
              ],
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
