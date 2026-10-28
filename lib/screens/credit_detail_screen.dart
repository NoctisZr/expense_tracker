import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/credit_purchase.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/amortization.dart';
import '../utils/formatters.dart';
import '../widgets/section_card.dart';

/// Detalle de una compra a crédito: progreso, cronograma de cuotas y acciones
/// (registrar la próxima cuota, ajustar tasa o plazo, anotar el monto real
/// cobrado por el banco, eliminar el plan).
class CreditDetailScreen extends StatelessWidget {
  final String creditId;
  const CreditDetailScreen({super.key, required this.creditId});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final CreditPurchase? credit = finance.creditById(creditId);

    if (credit == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final List<Installment> schedule = credit.schedule;
    final LoanSummary summary = credit.summary;
    final Installment? next = credit.nextInstallment;
    final double progress = schedule.isEmpty ? 0 : credit.registeredCount / schedule.length;
    final TextStyle small = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Text(value,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(credit.name, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(locale.t('saldo_pendiente'), formatCurrency(credit.outstanding, credit.currency), bold: true),
                  row(locale.t('falta_pagar'), formatCurrency(credit.remainingToPay, credit.currency)),
                  row(locale.t('monto_financiar'), formatCurrency(credit.financed, credit.currency)),
                  row(locale.t('intereses_totales'), formatCurrency(summary.totalInterest, credit.currency)),
                  row(locale.t('tcea'), formatPercent(summary.tcea)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble(), minHeight: 8),
                  const SizedBox(height: 4),
                  Text('${credit.registeredCount}/${schedule.length} ${locale.t('cuotas_registradas')}', style: small),
                  if (next != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${locale.t('proxima_cuota')}: ${formatDateShort(next.dueDate)} · '
                      '${formatCurrency(credit.amountFor(next.number), credit.currency)}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (next != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.read<FinanceProvider>().registerNextInstallment(credit.id),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(locale.t('registrar_cuota_ahora')),
                ),
              ),
            if (next != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _RenegotiateDialog(credit: credit),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(locale.t('ajustar_tasa_plazo')),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('tabla_amortizacion')),
                  const SizedBox(height: 6),
                  Text(locale.t('ajuste_manual_ayuda'), style: small),
                  const SizedBox(height: 8),
                  for (final s in schedule)
                    _InstallmentRow(credit: credit, installment: s, locale: locale),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => _confirmDelete(context, credit, locale),
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              label: Text(locale.t('eliminar_credito'), style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CreditPurchase credit, LocaleProvider locale) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_credito')),
        content: Text(locale.t('eliminar_credito_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(locale.t('cancelar'))),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteCredit(credit.id);
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  final CreditPurchase credit;
  final Installment installment;
  final LocaleProvider locale;

  const _InstallmentRow({required this.credit, required this.installment, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int n = installment.number;
    final bool done = n <= credit.registeredCount;
    final bool manual = credit.overrides.containsKey(n);
    final TextStyle small = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12);

    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _InstallmentAmountDialog(credit: credit, installment: installment),
      ),
      child: Opacity(
        opacity: done ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: done ? theme.colorScheme.primary : theme.hintColor,
              ),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: Text('$n', style: small)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDateShort(installment.dueDate), style: theme.textTheme.bodyMedium),
                    Text(
                      '${locale.t('capital')} ${formatAmount(installment.capital)} · '
                      '${locale.t('interes')} ${formatAmount(installment.interest)}',
                      style: small,
                    ),
                  ],
                ),
              ),
              if (manual) Icon(Icons.edit_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                formatAmount(credit.amountFor(n)),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anota lo que el banco cobró realmente en una cuota.
class _InstallmentAmountDialog extends StatefulWidget {
  final CreditPurchase credit;
  final Installment installment;
  const _InstallmentAmountDialog({required this.credit, required this.installment});

  @override
  State<_InstallmentAmountDialog> createState() => _InstallmentAmountDialogState();
}

class _InstallmentAmountDialogState extends State<_InstallmentAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.credit.amountFor(widget.installment.number).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _calculated => round2(widget.installment.total + (widget.installment.number == 1 ? widget.credit.upfrontFee : 0));

  void _save() {
    final double? value = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (value == null || value < 0) return;
    context.read<FinanceProvider>().setInstallmentAmount(
          widget.credit.id,
          widget.installment.number,
          (value - _calculated).abs() < 0.005 ? null : value,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final double? typed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final double? diff = typed == null ? null : round2(typed - _calculated);

    return AlertDialog(
      title: Text('${locale.t('ajustar_monto_cuota')} #${widget.installment.number}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: '${locale.t('monto')} (${widget.credit.currency})'),
          ),
          const SizedBox(height: 8),
          Text('${locale.t('calculado')}: ${formatAmount(_calculated)}', style: Theme.of(context).textTheme.bodySmall),
          if (diff != null && diff.abs() >= 0.005)
            Text(
              '${locale.t('diferencia_calculo')}: ${diff > 0 ? '+' : ''}${formatAmount(diff)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
      actions: [
        if (widget.credit.overrides.containsKey(widget.installment.number))
          TextButton(
            onPressed: () {
              context.read<FinanceProvider>().setInstallmentAmount(widget.credit.id, widget.installment.number, null);
              Navigator.of(context).pop();
            },
            child: Text(locale.t('quitar_ajuste')),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}

/// Cambia la tasa y/o el plazo de las cuotas que aún no se registraron.
class _RenegotiateDialog extends StatefulWidget {
  final CreditPurchase credit;
  const _RenegotiateDialog({required this.credit});

  @override
  State<_RenegotiateDialog> createState() => _RenegotiateDialogState();
}

class _RenegotiateDialogState extends State<_RenegotiateDialog> {
  late final TextEditingController _rate;
  late final TextEditingController _count;
  late String _rateType;

  @override
  void initState() {
    super.initState();
    final CreditPurchase c = widget.credit;
    _rateType = c.terms.rateType;
    _rate = TextEditingController(text: c.terms.ratePercent == 0 ? '' : c.terms.ratePercent.toString());
    _count = TextEditingController(text: '${c.totalInstallments - c.registeredCount}');
  }

  @override
  void dispose() {
    _rate.dispose();
    _count.dispose();
    super.dispose();
  }

  String _label(LocaleProvider l, String type) {
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

  CreditPurchase? _preview() {
    final int? n = int.tryParse(_count.text.trim());
    if (n == null || n < 1 || n > 360) return null;
    final double rate = double.tryParse(_rate.text.trim().replaceAll(',', '.')) ?? 0;
    return widget.credit.renegotiate(
      rateType: _rateType,
      ratePercent: _rateType == RateType.none ? 0 : rate,
      remainingInstallments: n,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final CreditPurchase? preview = _preview();
    final Installment? first = preview?.nextInstallment;

    return AlertDialog(
      title: Text(locale.t('ajustar_tasa_plazo')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locale.t('ajustar_tasa_ayuda'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in RateType.all)
                  ChoiceChip(
                    label: Text(_label(locale, type), style: const TextStyle(fontSize: 12)),
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
            const SizedBox(height: 8),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: locale.t('cuotas_restantes')),
            ),
            if (first != null) ...[
              const SizedBox(height: 10),
              Text(
                '${locale.t('nueva_cuota')}: ${formatCurrency(first.total, widget.credit.currency)}',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(
          onPressed: preview == null
              ? null
              : () {
                  context.read<FinanceProvider>().replaceCredit(preview);
                  Navigator.of(context).pop();
                },
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
