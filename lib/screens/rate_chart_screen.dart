import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rate_alert.dart';
import '../providers/currency_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import '../widgets/currency_dropdown.dart';
import '../widgets/section_card.dart';

/// Evolución de una tasa (con el historial guardado en el teléfono) y
/// alertas ("avísame si 1 USD llega a X BRL").
class RateChartScreen extends StatefulWidget {
  final String from;
  final String to;

  const RateChartScreen({super.key, required this.from, required this.to});

  @override
  State<RateChartScreen> createState() => _RateChartScreenState();
}

class _RateChartScreenState extends State<RateChartScreen> {
  late String _from = widget.from;
  late String _to = widget.to;
  int _days = 30;

  Future<void> _addAlert(CurrencyProvider currency, LocaleProvider locale) async {
    final double current = currency.canConvert(_from, _to) ? currency.convert(1, _from, _to) : 0;
    final TextEditingController controller =
        TextEditingController(text: current > 0 ? current.toStringAsFixed(current < 10 ? 3 : 2) : '');
    bool above = true;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(locale.t('nueva_alerta')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1 $_from =', style: Theme.of(dialogContext).textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(locale.t('alerta_sube'), style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: false, label: Text(locale.t('alerta_baja'), style: const TextStyle(fontSize: 12))),
                ],
                selected: {above},
                onSelectionChanged: (selection) => setDialogState(() => above = selection.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: '${locale.t('alerta_valor')} ($_to)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(locale.t('cancelar'))),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(locale.t('guardar'))),
          ],
        ),
      ),
    );
    final double? target = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (saved == true && target != null && target > 0) {
      await currency.addRateAlert(from: _from, to: _to, above: above, target: target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final List<MapEntry<DateTime, double>> series = currency.historyFor(_from, _to, _days);
    final List<RateAlert> alerts =
        currency.rateAlerts.where((a) => a.from == _from && a.to == _to).toList();

    double? minV, maxV, change;
    if (series.isNotEmpty) {
      minV = series.map((e) => e.value).reduce((a, b) => a < b ? a : b);
      maxV = series.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      if (series.length >= 2 && series.first.value != 0) {
        change = (series.last.value - series.first.value) / series.first.value * 100;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(locale.t('evolucion_tasa'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CurrencyDropdown(value: _from, onChanged: (v) => setState(() => _from = v)),
              const Icon(Icons.arrow_forward_rounded),
              CurrencyDropdown(value: _to, onChanged: (v) => setState(() => _to = v)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final d in const [7, 30, 90])
                ChoiceChip(
                  label: Text('$d ${locale.t('dias')}'),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            child: series.length < 2
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(locale.t('historial_insuficiente'), style: TextStyle(color: theme.hintColor)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 $_from = ${series.last.value.toStringAsFixed(series.last.value < 10 ? 4 : 2)} $_to',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (change != null)
                        Text(
                          '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(2)}% · ${series.length} ${locale.t('dias_con_datos')}',
                          style: TextStyle(
                            color: change >= 0 ? Colors.green : theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 170,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _LinePainter(
                            values: series.map((e) => e.value).toList(),
                            lineColor: theme.colorScheme.primary,
                            gridColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${locale.t('minimo')}: ${minV!.toStringAsFixed(minV < 10 ? 4 : 2)}', style: theme.textTheme.bodySmall),
                          Text('${locale.t('maximo')}: ${maxV!.toStringAsFixed(maxV < 10 ? 4 : 2)}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formatDateShort(series.first.key.toLocal()), style: theme.textTheme.bodySmall),
                          Text(formatDateShort(series.last.key.toLocal()), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SectionLabel(locale.t('alertas_de_tasa'), overflow: TextOverflow.ellipsis)),
                    IconButton(
                      onPressed: () => _addAlert(currency, locale),
                      icon: Icon(Icons.add_alert_outlined, color: theme.colorScheme.primary),
                      tooltip: locale.t('nueva_alerta'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (alerts.isEmpty)
                  Text(locale.t('sin_alertas'), style: TextStyle(color: theme.hintColor))
                else
                  for (final a in alerts)
                    Row(
                      children: [
                        Icon(a.above ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '1 ${a.from} ${a.above ? '≥' : '≤'} ${a.target} ${a.to}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => currency.deleteRateAlert(a.id),
                          icon: Icon(Icons.close, size: 18, color: theme.hintColor),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                const SizedBox(height: 6),
                Text(locale.t('alertas_ayuda'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea simple con cuadrícula horizontal; el eje vertical se ajusta al
/// mínimo y máximo de la serie.
class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  _LinePainter({required this.values, required this.lineColor, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final double minV = values.reduce((a, b) => a < b ? a : b);
    final double maxV = values.reduce((a, b) => a > b ? a : b);
    final double range = (maxV - minV).abs() < 1e-9 ? 1 : maxV - minV;

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final Paint line = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double y = size.height - ((values[i] - minV) / range) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);

    final double lastX = size.width;
    final double lastY = size.height - ((values.last - minV) / range) * (size.height - 8) - 4;
    canvas.drawCircle(Offset(lastX, lastY), 4.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.lineColor != lineColor || old.gridColor != gridColor;
}
