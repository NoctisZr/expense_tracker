import 'package:flutter/material.dart';
import '../models/income.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/mod_shapes.dart';

class IncomeCard extends StatelessWidget {
  final Income income;
  final VoidCallback onDelete;
  final VoidCallback onViewDetails;

  const IncomeCard({
    super.key,
    required this.income,
    required this.onDelete,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;
    final ShapeBorder shape = containerShapeBorderFor(extras.cardShapeKey, extras.cardRadius - 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onViewDetails,
          customBorder: shape,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: extras.success.withValues(alpha: 0.18),
              child: Icon(Icons.savings_rounded, color: extras.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    income.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(formatDateShort(income.date), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatCurrency(income.amount, income.currency),
                  maxLines: 1,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: extras.success),
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.close, size: 18, color: theme.hintColor),
              visualDensity: VisualDensity.compact,
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
