import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/credit_purchase.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/amortization.dart';
import '../utils/formatters.dart';
import '../utils/id_generator.dart';
import '../widgets/account_widgets.dart';
import '../widgets/category_selector_row.dart';
import '../widgets/currency_dropdown.dart';
import '../widgets/section_card.dart';

/// Calculadora de intereses: cuota, total, intereses, TCEA, tabla de
/// amortización, comparador de plazos, contado vs cuotas y pago adelantado.
/// Con [creditMode] el mismo formulario sirve para registrar una compra a
/// crédito (el botón principal guarda el plan).
class InterestCalculatorScreen extends StatefulWidget {
  final bool creditMode;
  const InterestCalculatorScreen({super.key, this.creditMode = false});

  @override
  State<InterestCalculatorScreen> createState() => _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _count = TextEditingController(text: '12');
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _upfront = TextEditingController();
  final TextEditingController _fee = TextEditingController();
  final TextEditingController _grace = TextEditingController();
  final TextEditingController _cash = TextEditingController();
  final TextEditingController _prepayAfter = TextEditingController(text: '1');
  final TextEditingController _prepayExtra = TextEditingController();

  late String _currency;
  String _rateType = RateType.tea;
  String _method = LoanMethod.french;
  bool _reduceTerm = true;

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    for (final c in [_amount, _count, _rate, _upfront, _fee, _grace, _cash, _prepayAfter, _prepayExtra]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  DateTime get _defaultFirstDue {
    final DateTime now = DateTime.now();
    return addMonthsClamped(DateTime(now.year, now.month, now.day, 9), 1);
  }

  LoanTerms? _terms({DateTime? firstDue, int? installments}) {
    final double amount = _num(_amount);
    final int n = installments ?? _int(_count);
    if (amount <= 0 || n < 1 || n > 360) return null;
    final int grace = _int(_grace).clamp(0, 24).toInt();
    return LoanTerms(
      principal: amount,
      installments: n,
      firstDue: firstDue ?? _defaultFirstDue,
      rateType: _rateType,
      ratePercent: _rateType == RateType.none ? 0 : _num(_rate),
      method: _method,
      installmentFee: _num(_fee),
      graceMonths: grace,
    );
  }

  String _rateTypeLabel(LocaleProvider l, String type) {
    switch (type) {
      case RateType.monthly:
        return l.t('tasa_mensual');
      case RateType.tea:
        return l.t('tasa_tea');
      case RateType.tna:
        return l.t('tasa_tna');
      default:
        return l.t('tasa_ninguna');
    }
  }

  String _methodLabel(LocaleProvider l, String method) {
    switch (method) {
      case LoanMethod.german:
        return l.t('metodo_aleman');
      case LoanMethod.flat:
        return l.t('metodo_plano');
      default:
        return l.t('metodo_frances');
    }
  }

  Future<void> _saveAsCredit(LoanTerms terms) async {
    final result = await showDialog<_CreditDetails>(
      context: context,
      builder: (_) => _CreditDetailsDialog(defaultFirstDue: terms.firstDue),
    );
    if (result == null || !mounted) return;
    final finance = context.read<FinanceProvider>();
    final DateTime due = DateTime(result.firstDue.year, result.firstDue.month, result.firstDue.day, 9);
    final LoanTerms real = terms.copyWith(firstDue: due);
    finance.addCredit(CreditPurchase(
      id: generateId(),
      name: result.name,
      category: result.category,
      purchaseDate: DateTime.now(),
      currency: _currency,
      accountId: result.accountId,
      financed: real.principal,
      upfrontFee: _num(_upfront),
      terms: real,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final LoanTerms? terms = _terms();
    final double upfront = _num(_upfront);
    final List<Installment> schedule = terms == null ? const [] : buildSchedule(terms);
    final LoanSummary? summary = terms == null ? null : summarize(terms.principal, upfront, schedule);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.creditMode ? locale.t('nueva_compra_credito') : locale.t('calculadora_intereses')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildInputs(locale, theme),
            const SizedBox(height: 14),
            if (summary == null || terms == null)
              SectionCard(child: Text(locale.t('cuotas_error'), style: TextStyle(color: theme.hintColor)))
            else ...[
              _buildResult(locale, theme, terms, summary),
              const SizedBox(height: 14),
              _buildTable(locale, theme, schedule),
              _buildCompare(locale, theme, terms, upfront),
              _buildCash(locale, theme, summary),
              _buildPrepay(locale, theme, terms, schedule),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveAsCredit(terms),
                  icon: const Icon(Icons.credit_score_rounded),
                  label: Text(widget.creditMode ? locale.t('guardar_compra_credito') : locale.t('usar_este_plan')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ entradas
  Widget _buildInputs(LocaleProvider locale, ThemeData theme) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: locale.t('monto_financiar')),
                ),
              ),
              const SizedBox(width: 10),
              CurrencyDropdown(value: _currency, dense: true, onChanged: (v) => setState(() => _currency = v)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: locale.t('num_cuotas')),
          ),
          const SizedBox(height: 12),
          Text(locale.t('tipo_tasa'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in RateType.all)
                ChoiceChip(
                  label: Text(_rateTypeLabel(locale, type), style: const TextStyle(fontSize: 12)),
                  selected: _rateType == type,
                  onSelected: (_) => setState(() => _rateType = type),
                ),
            ],
          ),
          if (_rateType != RateType.none) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: locale.t('valor_tasa')),
            ),
          ],
          const SizedBox(height: 12),
          Text(locale.t('metodo_cuotas'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in LoanMethod.all)
                ChoiceChip(
                  label: Text(_methodLabel(locale, m), style: const TextStyle(fontSize: 12)),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _upfront,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: locale.t('comision_inicial')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: locale.t('cargo_por_cuota')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _grace,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: locale.t('meses_gracia')),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- resultado
  Widget _buildResult(LocaleProvider locale, ThemeData theme, LoanTerms terms, LoanSummary s) {
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        );

    final double interestShare = s.totalPaid <= 0 ? 0 : (s.totalInterest / s.totalPaid).clamp(0.0, 1.0).toDouble();
    final int capitalFlex = ((1 - interestShare) * 1000).round().clamp(1, 999).toInt();
    final int interestFlex = (interestShare * 1000).round().clamp(0, 999).toInt();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.varies)
            row(locale.t('cuota_desde_hasta'),
                '${formatAmount(s.firstPayment)} → ${formatAmount(s.lastPayment)} $_currency', bold: true)
          else
            row(locale.t('cuota_mensual'), formatCurrency(s.firstPayment, _currency), bold: true),
          row(locale.t('total_a_pagar'), formatCurrency(s.totalPaid, _currency), bold: true),
          row(locale.t('intereses_totales'), formatCurrency(s.totalInterest, _currency)),
          row(locale.t('cargos_totales'), formatCurrency(s.totalFees, _currency)),
          row(locale.t('costo_extra'), formatCurrency(s.extraCost, _currency)),
          row(locale.t('tcea'), formatPercent(s.tcea), bold: true),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: capitalFlex, child: Container(color: theme.colorScheme.primary)),
                  if (interestFlex > 0) Expanded(flex: interestFlex, child: Container(color: theme.colorScheme.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${locale.t('capital')} ${formatPercent((1 - interestShare) * 100)}',
                  style: theme.textTheme.bodySmall),
              Text('${locale.t('interes')} ${formatPercent(interestShare * 100)}', style: theme.textTheme.bodySmall),
            ],
          ),
          if (terms.graceMonths > 0) ...[
            const SizedBox(height: 6),
            Text(locale.t('gracia_nota'), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _tile(ThemeData theme, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 6),
            childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildTable(LocaleProvider locale, ThemeData theme, List<Installment> schedule) {
    final TextStyle small = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    return _tile(theme, locale.t('tabla_amortizacion'), [
      Row(
        children: [
          SizedBox(width: 26, child: Text('#', style: small)),
          Expanded(flex: 3, child: Text(locale.t('col_cuota'), style: small)),
          Expanded(flex: 3, child: Text(locale.t('interes'), style: small)),
          Expanded(flex: 3, child: Text(locale.t('col_saldo'), style: small, textAlign: TextAlign.end)),
        ],
      ),
      for (final s in schedule)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(width: 26, child: Text('${s.number}', style: small)),
              Expanded(flex: 3, child: Text(formatAmount(s.total), style: small)),
              Expanded(flex: 3, child: Text(formatAmount(s.interest), style: small)),
              Expanded(flex: 3, child: Text(formatAmount(s.balanceAfter), style: small, textAlign: TextAlign.end)),
            ],
          ),
        ),
    ]);
  }

  Widget _buildCompare(LocaleProvider locale, ThemeData theme, LoanTerms terms, double upfront) {
    final TextStyle small = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
    final Map<int, LoanSummary> compared = compareTerms(terms, upfront, const [3, 6, 12, 18, 24, 36]);
    return _tile(theme, locale.t('comparar_plazos'), [
      Row(
        children: [
          Expanded(flex: 2, child: Text(locale.t('num_cuotas'), style: small)),
          Expanded(flex: 3, child: Text(locale.t('col_cuota'), style: small)),
          Expanded(flex: 3, child: Text(locale.t('intereses_totales'), style: small)),
          Expanded(flex: 2, child: Text(locale.t('tcea'), style: small, textAlign: TextAlign.end)),
        ],
      ),
      for (final e in compared.entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('${e.key}', style: small.copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text(formatAmount(e.value.firstPayment), style: small)),
              Expanded(flex: 3, child: Text(formatAmount(e.value.totalInterest), style: small)),
              Expanded(flex: 2, child: Text(formatPercent(e.value.tcea), style: small, textAlign: TextAlign.end)),
            ],
          ),
        ),
    ]);
  }

  Widget _buildCash(LocaleProvider locale, ThemeData theme, LoanSummary summary) {
    final double cash = _num(_cash);
    String? message;
    if (cash > 0) {
      final double diff = round2(summary.totalPaid - cash);
      final String x = formatCurrency(diff.abs(), _currency);
      message = diff >= 0
          ? locale.t('diferencia_contado_mas').replaceAll('{x}', x)
          : locale.t('diferencia_contado_menos').replaceAll('{x}', x);
    }
    return _tile(theme, locale.t('contado_vs_cuotas'), [
      TextField(
        controller: _cash,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: locale.t('precio_contado')),
      ),
      if (message != null) ...[
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    ]);
  }

  Widget _buildPrepay(LocaleProvider locale, ThemeData theme, LoanTerms terms, List<Installment> schedule) {
    final bool available = terms.method != LoanMethod.flat && schedule.length > 1;
    PrepayResult? result;
    if (available) {
      result = simulatePrepayment(
        terms,
        schedule,
        afterInstallment: _int(_prepayAfter),
        extra: _num(_prepayExtra),
        reduceTerm: _reduceTerm,
      );
    }
    return _tile(theme, locale.t('pago_adelantado'), [
      if (!available)
        Text(locale.t('pago_adelantado_no'), style: TextStyle(color: theme.hintColor))
      else ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _prepayAfter,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: locale.t('tras_la_cuota')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _prepayExtra,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: locale.t('abono_extra')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: true, label: Text(locale.t('reducir_plazo'), style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: false, label: Text(locale.t('reducir_cuota'), style: const TextStyle(fontSize: 12))),
            ],
            selected: {_reduceTerm},
            onSelectionChanged: (sel) => setState(() => _reduceTerm = sel.first),
          ),
        ),
        const SizedBox(height: 8),
        if (result != null) ...[
          Text(
            '${locale.t('ahorras_intereses')}: ${formatCurrency(result.interestSaved, _currency)}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (result.installmentsSaved > 0)
            Text('${result.installmentsSaved} ${locale.t('cuotas_menos')}', style: theme.textTheme.bodyMedium),
          if (result.newPayment > 0)
            Text('${locale.t('nueva_cuota')}: ${formatCurrency(result.newPayment, _currency)}',
                style: theme.textTheme.bodyMedium),
        ],
      ],
    ]);
  }
}

/// Datos que se piden al guardar el plan como compra a crédito.
class _CreditDetails {
  final String name;
  final String category;
  final String? accountId;
  final DateTime firstDue;

  const _CreditDetails({
    required this.name,
    required this.category,
    required this.accountId,
    required this.firstDue,
  });
}

class _CreditDetailsDialog extends StatefulWidget {
  final DateTime defaultFirstDue;
  const _CreditDetailsDialog({required this.defaultFirstDue});

  @override
  State<_CreditDetailsDialog> createState() => _CreditDetailsDialogState();
}

class _CreditDetailsDialogState extends State<_CreditDetailsDialog> {
  final TextEditingController _name = TextEditingController();
  String _category = ExpenseCategory.compras;
  String? _accountId;
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    _firstDue = widget.defaultFirstDue;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('campos_gasto_invalidos'))));
      return;
    }
    Navigator.of(context).pop(_CreditDetails(
      name: name,
      category: _category,
      accountId: _accountId,
      firstDue: _firstDue,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(locale.t('guardar_compra_credito')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('que_compraste')),
            ),
            const SizedBox(height: 12),
            CategorySelectorRow(selected: _category, locale: locale, onChanged: (c) => setState(() => _category = c)),
            const SizedBox(height: 8),
            AccountDropdown(value: _accountId, onChanged: (id) => setState(() => _accountId = id)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('${locale.t('primera_cuota_fecha')}: ${formatDateShort(_firstDue)}'),
            ),
            const SizedBox(height: 8),
            Text(locale.t('comision_suma_primera'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}
