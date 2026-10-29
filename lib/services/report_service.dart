import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import '../utils/pdf_report.dart';
import '../utils/report_stats.dart';

/// Arma y comparte el reporte mensual en PDF (texto simple, sin gráficos).
class ReportService {
  String _money(double value, String code) => '${formatAmount(value)} $code';

  /// Gasto total entre [start] (inclusive) y [end] (exclusivo), en moneda local.
  double _spentBetween(FinanceProvider finance, CurrencyProvider currency, DateTime start, DateTime end) {
    double total = 0;
    for (final e in finance.expensesInPeriod(start, end)) {
      total += finance.expenseLocalValue(e, currency);
    }
    return total;
  }

  /// Ingresos entre [start] (inclusive) y [end] (exclusivo), en moneda local.
  double _incomeBetween(FinanceProvider finance, CurrencyProvider currency, DateTime start, DateTime end) {
    double total = 0;
    for (final i in finance.incomes) {
      if (i.date.isBefore(start) || !i.date.isBefore(end)) continue;
      total += currency.convert(i.amount, i.currency, finance.localCurrency);
    }
    return total;
  }

  Map<String, double> _byCategory(FinanceProvider finance, CurrencyProvider currency, DateTime start, DateTime end) {
    final Map<String, double> result = {};
    for (final e in finance.expensesInPeriod(start, end)) {
      result[e.category] = (result[e.category] ?? 0) + finance.expenseLocalValue(e, currency);
    }
    return result;
  }

  String _deltaText(LocaleProvider locale, double current, double previous) =>
      deltaLabel(current, previous) ?? (current > 0 ? locale.t('reporte_nuevo') : '-');

  /// Comparativa con el mes anterior (texto) para el PDF.
  List<String> _comparisonLines({
    required FinanceProvider finance,
    required CurrencyProvider currency,
    required LocaleProvider locale,
    required DateTime month,
    required double totalExpenses,
    required double totalIncome,
  }) {
    final String local = finance.localCurrency;
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime prevStart = DateTime(month.year, month.month - 1, 1);
    final double prevSpent = _spentBetween(finance, currency, prevStart, start);
    final double prevIncome = _incomeBetween(finance, currency, prevStart, start);
    if (prevSpent <= 0 && prevIncome <= 0) return const [];

    final Map<String, double> now = _byCategory(finance, currency, start, DateTime(month.year, month.month + 1, 1));
    final Map<String, double> before = _byCategory(finance, currency, prevStart, start);
    final Set<String> cats = {...now.keys, ...before.keys};
    final List<MapEntry<String, double>> diffs = [
      for (final c in cats) MapEntry(c, (now[c] ?? 0) - (before[c] ?? 0)),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final List<String> lines = [
      '',
      locale.t('reporte_comparativa').toUpperCase(),
      '  ${locale.t('reporte_gastos_mes_ant')}: ${_money(prevSpent, local)} (${_deltaText(locale, totalExpenses, prevSpent)})',
      '  ${locale.t('reporte_ingresos_mes_ant')}: ${_money(prevIncome, local)} (${_deltaText(locale, totalIncome, prevIncome)})',
    ];
    final List<MapEntry<String, double>> up = diffs.where((e) => e.value > 0.004).take(3).toList();
    final List<MapEntry<String, double>> down =
        diffs.reversed.where((e) => e.value < -0.004).take(3).toList();
    if (up.isNotEmpty) {
      lines.add('  ${locale.t('reporte_suben')}:');
      for (final e in up) {
        lines.add('    ${locale.t(categoryLabelKey(e.key))}: +${_money(e.value, local)}');
      }
    }
    if (down.isNotEmpty) {
      lines.add('  ${locale.t('reporte_bajan')}:');
      for (final e in down) {
        lines.add('    ${locale.t(categoryLabelKey(e.key))}: -${_money(-e.value, local)}');
      }
    }
    return lines;
  }

  List<String> buildLines({
    required FinanceProvider finance,
    required CurrencyProvider currency,
    required LocaleProvider locale,
    required DateTime month,
  }) {
    final String local = finance.localCurrency;
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);

    final List<Expense> expenses = finance.expensesInPeriod(start, end)
      ..sort((a, b) => finance
          .expenseLocalValue(b, currency)
          .compareTo(finance.expenseLocalValue(a, currency)));

    double totalExpenses = 0;
    final Map<String, double> byCategory = {};
    for (final e in expenses) {
      final double v = finance.expenseLocalValue(e, currency);
      totalExpenses += v;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + v;
    }

    double totalIncome = 0;
    for (final i in finance.incomes) {
      if (i.date.isBefore(start) || !i.date.isBefore(end)) continue;
      totalIncome += currency.convert(i.amount, i.currency, local);
    }

    final List<String> lines = [
      '${locale.t('espacio_activo')}: ${finance.activeWorkspace.name}',
      '${locale.t('reporte_periodo')}: ${month.month.toString().padLeft(2, '0')}/${month.year}',
      '${locale.t('moneda_local')}: $local',
      '',
      '${locale.t('ingresos_del_mes')}: ${_money(totalIncome, local)}',
      '${locale.t('gastos_del_mes')}: ${_money(totalExpenses, local)}',
      '${locale.t('balance_del_mes')}: ${_money(totalIncome - totalExpenses, local)}',
      ..._comparisonLines(
        finance: finance,
        currency: currency,
        locale: locale,
        month: month,
        totalExpenses: totalExpenses,
        totalIncome: totalIncome,
      ),
      '',
      locale.t('reporte_por_categoria').toUpperCase(),
    ];

    if (byCategory.isEmpty) {
      lines.add('  -');
    } else {
      final List<MapEntry<String, double>> sorted = byCategory.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        final double pct = totalExpenses <= 0 ? 0 : entry.value / totalExpenses * 100;
        lines.add('  ${locale.t(categoryLabelKey(entry.key))}: ${_money(entry.value, local)} (${pct.toStringAsFixed(0)}%)');
      }
    }

    final Map<String, double> budgets = finance.budgets;
    if (budgets.isNotEmpty) {
      lines
        ..add('')
        ..add(locale.t('reporte_presupuestos').toUpperCase());
      for (final entry in budgets.entries) {
        final double spent = byCategory[entry.key] ?? 0;
        lines.add('  ${locale.t(categoryLabelKey(entry.key))}: ${_money(spent, local)} / ${_money(entry.value, local)}');
      }
    }

    lines
      ..add('')
      ..add(locale.t('gastos_mayores').toUpperCase());
    if (expenses.isEmpty) {
      lines.add('  -');
    } else {
      for (final e in expenses.take(10)) {
        lines.add('  ${formatDateShort(e.date)}  ${e.name}  -  ${_money(e.amount, e.currency)}');
      }
    }

    lines
      ..add('')
      ..add('${locale.t('reporte_total_gastos')}: ${expenses.length}');
    return lines;
  }

  Future<void> shareMonthlyReport({
    required FinanceProvider finance,
    required CurrencyProvider currency,
    required LocaleProvider locale,
    required DateTime month,
  }) async {
    final List<String> lines =
        buildLines(finance: finance, currency: currency, locale: locale, month: month);
    // Barras de gasto por categoría (las 8 mayores) para el gráfico del PDF.
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 1);
    final Map<String, double> byCategory = {};
    for (final e in finance.expensesInPeriod(start, end)) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + finance.expenseLocalValue(e, currency);
    }
    final List<MapEntry<String, double>> bars = byCategory.entries
        .map((e) => MapEntry(locale.t(categoryLabelKey(e.key)), e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Gráficos extra: evolución de los últimos 6 meses e ingresos vs gastos.
    final List<MapEntry<String, double>> evolution = [];
    for (int back = 5; back >= 0; back--) {
      final DateTime s = DateTime(month.year, month.month - back, 1);
      final DateTime e = DateTime(month.year, month.month - back + 1, 1);
      evolution.add(MapEntry(
        '${s.month.toString().padLeft(2, '0')}/${s.year}',
        _spentBetween(finance, currency, s, e),
      ));
    }
    final double monthIncome = _incomeBetween(finance, currency, start, end);
    final double monthSpent = _spentBetween(finance, currency, start, end);

    final Uint8List pdf = buildSimplePdf(
      title: '${locale.t('reporte_titulo')} ${month.month.toString().padLeft(2, '0')}/${month.year}',
      lines: lines,
      barsTitle: '${locale.t('reporte_por_categoria')} (${finance.localCurrency})',
      bars: bars.take(8).toList(),
      extraCharts: [
        PdfChart(
          title: '${locale.t('reporte_evolucion')} (${finance.localCurrency})',
          bars: evolution,
          rgb: const [0.25, 0.45, 0.85],
        ),
        PdfChart(
          title: '${locale.t('reporte_ingresos_vs_gastos')} (${finance.localCurrency})',
          bars: [
            MapEntry(locale.t('ingresos_del_mes'), monthIncome),
            MapEntry(locale.t('gastos_del_mes'), monthSpent),
          ],
          rgb: const [0.9, 0.5, 0.2],
        ),
      ],
    );
    final Directory temp = await getTemporaryDirectory();
    final File file = File(
      '${temp.path}/reporte_${month.year}_${month.month.toString().padLeft(2, '0')}.pdf',
    );
    await file.writeAsBytes(pdf);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: locale.t('reporte_titulo'),
    );
  }
}
