import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/couple_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import '../utils/payment_schedule.dart';
import 'section_card.dart';

const List<String> _months = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const List<String> _weekdays = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

/// Calendario de pagos: lo que viene (gastos recurrentes, cuotas de créditos,
/// gastos fijos de pareja e ingresos esperados), con el total por pagar del
/// mes, el próximo pago y el detalle de cada día.
class PaymentCalendarSection extends StatefulWidget {
  const PaymentCalendarSection({super.key});

  @override
  State<PaymentCalendarSection> createState() => _PaymentCalendarSectionState();
}

class _PaymentCalendarSectionState extends State<PaymentCalendarSection> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selected = DateTime(now.year, now.month, now.day);
  }

  void _go(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      final DateTime now = DateTime.now();
      _selected = (_month.year == now.year && _month.month == now.month)
          ? DateTime(now.year, now.month, now.day)
          : _month;
    });
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<ScheduledItem> _items(FinanceProvider finance, CoupleProvider couple, DateTime from, DateTime to) {
    final bool coupleOn = couple.isLinked && couple.workspaceId == finance.activeWorkspaceId;
    return scheduledForRange(
      from: from,
      to: to,
      expenses: finance.recurringExpenses,
      incomes: finance.recurringIncomes,
      credits: finance.credits,
      fixed: coupleOn ? couple.fixedExpenses : const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final couple = context.watch<CoupleProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final String local = finance.localCurrency;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    double toLocal(double v, String c) => (c.isEmpty || c == local) ? v : currency.convert(v, c, local);

    final range = monthRange(_month);
    final List<ScheduledItem> items = _items(finance, couple, range.from, range.to);
    final Map<int, List<ScheduledItem>> byDay = {};
    for (final i in items) {
      byDay.putIfAbsent(i.date.day, () => []).add(i);
    }

    // Totales del mes (en el mes actual solo lo que aún no pasó).
    final DateTime countFrom = (_month.year == now.year && _month.month == now.month) ? today : range.from;
    double toPay = 0;
    double expectedIncome = 0;
    for (final i in items) {
      if (i.date.isBefore(countFrom)) continue;
      final double v = toLocal(i.amount, i.currency);
      i.isIncome ? expectedIncome += v : toPay += v;
    }

    // Próximo pago (en los próximos 90 días).
    final List<ScheduledItem> upcoming =
        _items(finance, couple, now, DateTime(now.year, now.month, now.day + 90)).where((i) => !i.isIncome).toList();
    final ScheduledItem? next = upcoming.isEmpty ? null : upcoming.first;

    final Set<int> recordedDays = finance.expenses
        .where((e) => e.date.year == _month.year && e.date.month == _month.month)
        .map((e) => e.date.day)
        .toSet();

    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final int leading = DateTime(_month.year, _month.month, 1).weekday % 7; // domingo = 0
    final int cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final Color outColor = theme.colorScheme.error;
    final Color inColor = theme.colorScheme.primary;
    final Color recColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    final List<ScheduledItem> dayItems = byDay[_selected.day] ?? const [];
    final List<Expense> dayRecorded = (_selected.year == _month.year && _selected.month == _month.month)
        ? finance.expensesOnDay(_selected)
        : const [];

    String nextText = '';
    if (next != null) {
      final int days = DateTime(next.date.year, next.date.month, next.date.day).difference(today).inDays;
      final String when = days <= 0
          ? locale.t('cal_hoy')
          : days == 1
              ? locale.t('cal_manana')
              : locale.t('cal_en_dias').replaceAll('{n}', '$days');
      nextText = '${next.title} · $when · ${formatCurrency(next.amount, next.currency)}';
    }

    Widget stat(String label, double value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatCurrency(value, local),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),
        );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('cal_titulo')),
          const SizedBox(height: 4),
          Text(locale.t('cal_ayuda'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          if (next != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${locale.t('cal_proximo')}: $nextText',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              stat(locale.t('cal_por_pagar'), toPay, outColor),
              const SizedBox(width: 10),
              stat(locale.t('cal_ingresos'), expectedIncome, inColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () => _go(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: locale.t('mes_anterior'),
              ),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => _go(1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: locale.t('mes_siguiente'),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(child: Center(child: Text(w, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.92),
            itemCount: cells,
            itemBuilder: (_, index) {
              final int day = index - leading + 1;
              if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
              final DateTime date = DateTime(_month.year, _month.month, day);
              final List<ScheduledItem> list = byDay[day] ?? const [];
              final bool hasOut = list.any((i) => !i.isIncome);
              final bool hasIn = list.any((i) => i.isIncome);
              final bool selected = _sameDay(date, _selected);
              final bool isToday = _sameDay(date, today);
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _selected = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected ? theme.colorScheme.primary.withValues(alpha: 0.20) : Colors.transparent,
                    border: isToday ? Border.all(color: theme.colorScheme.primary, width: 1.4) : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontWeight: selected || isToday ? FontWeight.bold : FontWeight.w500)),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasOut) _Dot(outColor),
                            if (hasIn) _Dot(inColor),
                            if (recordedDays.contains(day)) _Dot(recColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            children: [
              _Legend(outColor, locale.t('cal_leyenda_pago')),
              _Legend(inColor, locale.t('cal_leyenda_ingreso')),
              _Legend(recColor, locale.t('cal_leyenda_reg')),
            ],
          ),
          const Divider(height: 24),
          Text(
            '${_selected.day} ${_months[_selected.month - 1]}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (dayItems.isEmpty && dayRecorded.isEmpty)
            Text(locale.t('cal_nada'), style: TextStyle(color: theme.hintColor)),
          for (final i in dayItems) _ItemRow(item: i, local: local, currency: currency, locale: locale),
          if (dayRecorded.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(locale.t('cal_registrados'), style: theme.textTheme.bodySmall),
            for (final e in dayRecorded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(categoryIcon(e.category), size: 18, color: categoryColor(e.category)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(formatCurrency(e.amount, e.currency), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1.2),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend(this.color, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _ItemRow extends StatelessWidget {
  final ScheduledItem item;
  final String local;
  final CurrencyProvider currency;
  final LocaleProvider locale;
  const _ItemRow({required this.item, required this.local, required this.currency, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final IconData icon;
    late final String kindText;
    switch (item.kind) {
      case ScheduledKind.expense:
        icon = Icons.event_repeat_rounded;
        kindText = locale.t('cal_gasto_rec');
        break;
      case ScheduledKind.income:
        icon = Icons.south_west_rounded;
        kindText = locale.t('cal_ingreso_rec');
        break;
      case ScheduledKind.installment:
        icon = Icons.credit_score_rounded;
        kindText = locale.t('cal_cuota');
        break;
      case ScheduledKind.fixed:
        icon = Icons.call_split_rounded;
        kindText = locale.t('cal_fijo');
        break;
    }
    final Color color = item.isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    final bool convertible = item.currency.isNotEmpty && item.currency != local && currency.canConvert(item.currency, local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$kindText · ${locale.t('cal_programado')}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.isIncome ? '+' : '-'}${formatCurrency(item.amount, item.currency)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              if (convertible)
                Text('≈ ${formatCurrency(currency.convert(item.amount, item.currency, local), local)}',
                    style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
