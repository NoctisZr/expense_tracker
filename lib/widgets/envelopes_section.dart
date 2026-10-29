import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/envelopes.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';
import 'section_card.dart';

/// Sobres: repartes los ingresos del mes en sobres (por defecto 50/30/20) y
/// cada sobre descuenta los gastos de las categorías que le asignes.
class EnvelopesSection extends StatelessWidget {
  const EnvelopesSection({super.key});

  List<Envelope> _localizedDefaults(LocaleProvider locale) {
    const Map<String, String> keys = {
      'env_needs': 'sobre_necesidades',
      'env_wants': 'sobre_deseos',
      'env_save': 'sobre_ahorro',
    };
    return [
      for (final e in defaultEnvelopes()) e.copyWith(name: locale.t(keys[e.id] ?? 'sobres')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final List<Envelope> envelopes = finance.envelopes;
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
    final double income = finance.incomeInRangeLocal(currency, start, nextMonth.subtract(const Duration(seconds: 1)));
    final Map<String, double> byCategory = {};
    for (final e in finance.expensesInPeriod(start, nextMonth)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + finance.expenseLocalValue(e, currency);
    }
    final List<EnvelopeStatus> statuses = envelopeStatuses(envelopes, income, byCategory);
    final double unassigned = unassignedSpend(envelopes, byCategory);
    final double percentSum = totalPercent(envelopes);
    final String local = finance.localCurrency;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('sobres'))),
              if (envelopes.isNotEmpty)
                IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _EnvelopeDialog(existing: null, all: envelopes),
                  ),
                  icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                  tooltip: locale.t('sobre_nuevo'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (envelopes.isEmpty) ...[
            Text(locale.t('sobres_ayuda'), style: TextStyle(color: theme.hintColor)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.read<FinanceProvider>().saveEnvelopes(_localizedDefaults(locale)),
              icon: const Icon(Icons.pie_chart_outline_rounded),
              label: Text(locale.t('sobres_usar_5030')),
            ),
          ] else ...[
            if (income <= 0)
              Text(locale.t('regla_sin_ingresos'), style: TextStyle(color: theme.hintColor))
            else
              Text('${locale.t('ingresos_del_mes')}: ${formatCurrency(income, local)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            for (final s in statuses)
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => _EnvelopeDialog(existing: s.envelope, all: envelopes),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${s.envelope.name} · ${s.envelope.percent.toStringAsFixed(s.envelope.percent % 1 == 0 ? 0 : 1)} %',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatCurrency(s.allocated, local),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: s.isReserve ? 1 : s.progress,
                        minHeight: 7,
                        semanticsLabel: '${s.envelope.name} ${(s.progress * 100).round()} %',
                        color: s.over ? theme.colorScheme.error : null,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.isReserve
                            ? locale.t('sobre_reserva')
                            : s.over
                                ? '${locale.t('sobre_te_pasaste')} ${formatCurrency(-s.remaining, local)}'
                                : '${locale.t('sobre_gastado')} ${formatCurrency(s.spent, local)} · ${locale.t('sobre_queda')} ${formatCurrency(s.remaining, local)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: s.over ? theme.colorScheme.error : null),
                      ),
                    ],
                  ),
                ),
              ),
            if ((percentSum - 100).abs() > 0.01)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${locale.t('sobres_suma')} ${percentSum.toStringAsFixed(percentSum % 1 == 0 ? 0 : 1)} %',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (unassigned > 0.004)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${locale.t('sobres_sin_sobre')}: ${formatCurrency(unassigned, local)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EnvelopeDialog extends StatefulWidget {
  final Envelope? existing;
  final List<Envelope> all;
  const _EnvelopeDialog({required this.existing, required this.all});

  @override
  State<_EnvelopeDialog> createState() => _EnvelopeDialogState();
}

class _EnvelopeDialogState extends State<_EnvelopeDialog> {
  late final TextEditingController _name;
  late final TextEditingController _percent;
  late Set<String> _categories;

  @override
  void initState() {
    super.initState();
    final Envelope? e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _percent = TextEditingController(text: e == null ? '' : e.percent.toString());
    _categories = {...?e?.categories};
  }

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String name = _name.text.trim();
    final double? percent = double.tryParse(_percent.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || percent == null || percent < 0 || percent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('campos_gasto_invalidos'))));
      return;
    }
    final Envelope saved = (widget.existing ?? Envelope(id: generateId(), name: name, percent: percent))
        .copyWith(name: name, percent: percent, categories: _categories.toList());
    final List<Envelope> list = widget.existing == null
        ? [...widget.all, saved]
        : widget.all.map((e) => e.id == saved.id ? saved : e).toList();
    context.read<FinanceProvider>().saveEnvelopes(list);
    Navigator.of(context).pop();
  }

  void _delete() {
    context.read<FinanceProvider>().saveEnvelopes(widget.all.where((e) => e.id != widget.existing!.id).toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    // Se observa FinanceProvider por si se crean categorías propias.
    context.watch<FinanceProvider>();

    return AlertDialog(
      title: Text(widget.existing == null ? locale.t('sobre_nuevo') : locale.t('sobre_editar')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _percent,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: locale.t('sobre_porcentaje')),
            ),
            const SizedBox(height: 12),
            Text(locale.t('sobre_categorias'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final cat in ExpenseCategory.all)
                  FilterChip(
                    label: Text(locale.t(categoryLabelKey(cat)), style: const TextStyle(fontSize: 12)),
                    selected: _categories.contains(cat),
                    onSelected: (on) => setState(() {
                      if (on) {
                        _categories.add(cat);
                      } else {
                        _categories.remove(cat);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(locale.t('sobre_categorias_ayuda'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _delete,
            child: Text(locale.t('eliminar'), style: TextStyle(color: theme.colorScheme.error)),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}
