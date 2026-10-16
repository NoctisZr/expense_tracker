import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/mod_shapes.dart';

class _DonutSection {
  final String label;
  final double percent;
  final Color color;
  _DonutSection(this.label, this.percent, this.color);
}

/// Gráfico de dona interactivo (fl_chart) que muestra cómo se repartió
/// el ÚLTIMO ingreso registrado entre Gastos, Bóvedas y Balance
/// Disponible, desde la fecha de ese ingreso hasta hoy.
class BalanceDonutChart extends StatefulWidget {
  final double incomeAmount;
  final DateTime? incomeDate;
  final double periodExpenses;
  final double periodVaultNet;
  final String currency;
  final String balanceLibreLabel;
  final String disponibleLabel;
  final String gastosLabel;
  final String bovedasLabel;
  final String desdeLabel;
  final String sinIngresosPrompt;
  final String balanceNegativoTitulo;
  final String balanceNegativoMensaje;

  const BalanceDonutChart({
    super.key,
    required this.incomeAmount,
    required this.incomeDate,
    required this.periodExpenses,
    required this.periodVaultNet,
    required this.currency,
    required this.balanceLibreLabel,
    required this.disponibleLabel,
    required this.gastosLabel,
    required this.bovedasLabel,
    required this.desdeLabel,
    required this.sinIngresosPrompt,
    required this.balanceNegativoTitulo,
    required this.balanceNegativoMensaje,
  });

  @override
  State<BalanceDonutChart> createState() => _BalanceDonutChartState();
}

class _BalanceDonutChartState extends State<BalanceDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.incomeDate == null || widget.incomeAmount <= 0) {
      return _EmptyState(message: widget.sinIngresosPrompt);
    }

    final double freeBalance =
        widget.incomeAmount - widget.periodExpenses - widget.periodVaultNet;

    if (freeBalance < 0) {
      return _NegativeBalanceState(
        amount: freeBalance,
        currency: widget.currency,
        balanceLibreLabel: widget.balanceLibreLabel,
        titulo: widget.balanceNegativoTitulo,
        mensaje: widget.balanceNegativoMensaje,
      );
    }

    final accent = Theme.of(context).colorScheme.primary;
    final extras = Theme.of(context).extension<AppThemeExtras>()!;
    final double expensesPct =
        (widget.periodExpenses / widget.incomeAmount * 100).clamp(0, 100).toDouble();
    final double vaultsPct =
        (widget.periodVaultNet / widget.incomeAmount * 100).clamp(0, 100).toDouble();
    final double freePct = (100 - expensesPct - vaultsPct).clamp(0, 100).toDouble();

    final sections = <_DonutSection>[
      _DonutSection(widget.gastosLabel, expensesPct, extras.expense),
      _DonutSection(widget.bovedasLabel, vaultsPct, extras.vault),
      _DonutSection(widget.disponibleLabel, freePct, accent),
    ];

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 64,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex =
                            pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(sections.length, (i) {
                    final section = sections[i];
                    final bool isTouched = i == _touchedIndex;
                    final bool showLabel = section.percent >= 4;
                    return PieChartSectionData(
                      value: section.percent,
                      color: section.color,
                      radius: isTouched ? 54 : 46,
                      showTitle: showLabel,
                      title: showLabel
                          ? '${section.label}\n${formatPercent(section.percent)}'
                          : '',
                      titlePositionPercentageOffset: 0.62,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 13 : 11,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: AppColors.onColorFor(section.color),
                      ),
                    );
                  }),
                ),
                swapAnimationDuration: const Duration(milliseconds: 500),
                swapAnimationCurve: Curves.easeOutCubic,
              ),
              _CenterLabel(
                title: widget.balanceLibreLabel,
                amount: freeBalance,
                currency: widget.currency,
                color: accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.desdeLabel} ${formatDateShort(widget.incomeDate!)}',
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _CenterLabel extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final Color color;

  const _CenterLabel({
    required this.title,
    required this.amount,
    required this.currency,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.5,
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatAmount(amount),
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        Text(
          currency,
          style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15),
      ),
    );
  }
}

class _NegativeBalanceState extends StatelessWidget {
  final double amount;
  final String currency;
  final String balanceLibreLabel;
  final String titulo;
  final String mensaje;

  const _NegativeBalanceState({
    required this.amount,
    required this.currency,
    required this.balanceLibreLabel,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final Color warningColor = theme.colorScheme.error;
    final extras = theme.extension<AppThemeExtras>()!;
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 64,
                  sections: [
                    PieChartSectionData(
                      value: 1,
                      color: warningColor,
                      radius: 46,
                      showTitle: false,
                    ),
                  ],
                ),
                swapAnimationDuration: const Duration(milliseconds: 500),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    balanceLibreLabel,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatAmount(amount),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: warningColor,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    currency,
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: warningColor.withValues(alpha: 0.12),
            borderRadius: borderRadiusApproxFor(extras.cardShapeKey, extras.cardRadius - 6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: warningColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mensaje,
                      style: TextStyle(color: onSurface.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
