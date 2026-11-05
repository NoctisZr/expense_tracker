import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/expense_filter.dart';
import '../utils/formatters.dart';

/// Búsqueda y filtros de Movimientos: un buscador siempre visible, periodos
/// rápidos de un toque, y una hoja con todos los filtros (categorías,
/// etiquetas, cuenta, moneda, monto, tipo y orden).
class ExpenseFilterBar extends StatefulWidget {
  final ExpenseFilter filter;
  final ValueChanged<ExpenseFilter> onChanged;

  /// Resultado del filtro (para el resumen): cantidad y total en moneda local.
  final int resultCount;
  final double resultTotal;

  const ExpenseFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.resultCount,
    required this.resultTotal,
  });

  @override
  State<ExpenseFilterBar> createState() => _ExpenseFilterBarState();
}

class _ExpenseFilterBarState extends State<ExpenseFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filter.query);
  }

  @override
  void didUpdateWidget(covariant ExpenseFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si se limpiaron los filtros desde fuera, se vacía también el buscador.
    if (widget.filter.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.filter.query,
        selection: TextSelection.collapsed(offset: widget.filter.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(ExpenseFilter f) => widget.onChanged(f);

  Future<void> _openSheet() async {
    final ExpenseFilter? result = await showModalBottomSheet<ExpenseFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: widget.filter),
    );
    if (result != null) _set(result);
  }

  Future<void> _pickRange() async {
    final DateTime now = DateTime.now();
    final f = widget.filter;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (f.from != null && f.to != null) ? DateTimeRange(start: f.from!, end: f.to!) : null,
    );
    if (picked != null) _set(f.copyWith(from: picked.start, to: picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final theme = Theme.of(context);
    final f = widget.filter;
    final DateTime now = DateTime.now();
    final String? period = matchingPeriod(f.from, f.to, now);
    final bool noRange = f.from == null && f.to == null;
    final bool customRange = !noRange && period == null;

    Widget periodChip(String? key, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label, style: const TextStyle(fontSize: 12.5)),
            selected: key == null ? noRange : period == key,
            onSelected: (_) {
              if (key == null) {
                _set(f.copyWith(clearRange: true));
              } else {
                final r = periodRange(key, now);
                _set(f.copyWith(from: r.from, to: r.to));
              }
            },
          ),
        );

    // Chips de los filtros activos (cada uno se quita con su ×).
    final List<Widget> active = [];
    Widget inputChip(String label, VoidCallback onDelete) => InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: onDelete,
          visualDensity: VisualDensity.compact,
        );
    if (f.categories.isNotEmpty) {
      final List<String> names = f.categories.map((c) => locale.t(categoryLabelKey(c))).toList();
      final String text = names.length <= 2 ? names.join(', ') : '${names.take(2).join(', ')} +${names.length - 2}';
      active.add(inputChip(text, () => _set(f.copyWith(categories: const {}))));
    }
    if (f.tags.isNotEmpty) {
      active.add(inputChip(f.tags.map((t) => '#$t').join(' '), () => _set(f.copyWith(tags: const {}))));
    }
    if (customRange) {
      final String a = f.from == null ? '…' : formatDateShort(f.from!);
      final String b = f.to == null ? '…' : formatDateShort(f.to!);
      active.add(inputChip('$a – $b', () => _set(f.copyWith(clearRange: true))));
    }
    if (f.accountId != null) {
      String name = '?';
      for (final a in finance.accounts) {
        if (a.id == f.accountId) name = a.name;
      }
      active.add(inputChip(name, () => _set(f.copyWith(clearAccount: true))));
    }
    if (f.currency != null) active.add(inputChip(f.currency!, () => _set(f.copyWith(clearCurrency: true))));
    if (f.minAmount != null || f.maxAmount != null) {
      final String lo = f.minAmount == null ? '' : formatAmount(f.minAmount!);
      final String hi = f.maxAmount == null ? '' : formatAmount(f.maxAmount!);
      active.add(inputChip('$lo – $hi', () => _set(f.copyWith(clearMin: true, clearMax: true))));
    }
    if (f.kind != ExpenseKindFilter.any) {
      active.add(inputChip(_kindLabel(locale, f.kind), () => _set(f.copyWith(kind: ExpenseKindFilter.any))));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onChanged: (v) => _set(f.copyWith(query: v)),
                decoration: InputDecoration(
                  hintText: locale.t('buscar_gastos'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _set(f.copyWith(query: ''));
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton.filledTonal(
                  onPressed: _openSheet,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: locale.t('flt_filtros'),
                ),
                if (f.activeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                      child: Text(
                        '${f.activeCount}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              periodChip(null, locale.t('flt_p_todo')),
              periodChip('today', locale.t('flt_p_hoy')),
              periodChip('week', locale.t('flt_p_semana')),
              periodChip('month', locale.t('flt_p_mes')),
              periodChip('lastMonth', locale.t('flt_p_mes_pasado')),
              periodChip('year', locale.t('flt_p_anio')),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(locale.t('flt_p_otro'), style: const TextStyle(fontSize: 12.5)),
                onPressed: _pickRange,
              ),
            ],
          ),
        ),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 0, children: active),
        ],
        if (f.isActive) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.resultCount == 0
                      ? locale.t('sin_resultados')
                      : '${widget.resultCount} ${locale.t('flt_resultados')} · ${locale.t('flt_total')} ${formatCurrency(widget.resultTotal, finance.localCurrency)}'
                          ' · ${locale.t('flt_promedio')} ${formatCurrency(widget.resultTotal / widget.resultCount, finance.localCurrency)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => _set(const ExpenseFilter()),
                child: Text(locale.t('flt_limpiar_todo')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _kindLabel(LocaleProvider l, ExpenseKindFilter k) {
  switch (k) {
    case ExpenseKindFilter.personal:
      return l.t('flt_tipo_personal');
    case ExpenseKindFilter.couple:
      return l.t('flt_tipo_pareja');
    case ExpenseKindFilter.credit:
      return l.t('flt_tipo_credito');
    case ExpenseKindFilter.any:
      return l.t('flt_tipo_todos');
  }
}

String _sortLabel(LocaleProvider l, ExpenseSort s) {
  switch (s) {
    case ExpenseSort.newest:
      return l.t('flt_mas_recientes');
    case ExpenseSort.oldest:
      return l.t('flt_mas_antiguos');
    case ExpenseSort.amountDesc:
      return l.t('flt_mayor_monto');
    case ExpenseSort.amountAsc:
      return l.t('flt_menor_monto');
  }
}

// ------------------------------------------------------------ hoja de filtros
class _FilterSheet extends StatefulWidget {
  final ExpenseFilter initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ExpenseFilter _f;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    _f = widget.initial;
    _min = TextEditingController(text: _f.minAmount == null ? '' : _f.minAmount!.toString());
    _max = TextEditingController(text: _f.maxAmount == null ? '' : _f.maxAmount!.toString());
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _apply() {
    final double? lo = _num(_min);
    final double? hi = _num(_max);
    Navigator.of(context).pop(_f.copyWith(
      minAmount: lo,
      clearMin: lo == null,
      maxAmount: hi,
      clearMax: hi == null,
    ));
  }

  void _clear() {
    // Se conserva el texto de búsqueda: solo se limpian los filtros.
    Navigator.of(context).pop(ExpenseFilter(query: _f.query));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final theme = Theme.of(context);
    final List<String> tags = finance.topTags(limit: 20);
    final List<String> currencies = (finance.expenses.map((e) => e.currency).toSet().toList()..sort());

    Widget title(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(locale.t('flt_filtros'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      title(locale.t('flt_orden')),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final s in ExpenseSort.values)
                            ChoiceChip(
                              label: Text(_sortLabel(locale, s), style: const TextStyle(fontSize: 12.5)),
                              selected: _f.sort == s,
                              onSelected: (_) => setState(() => _f = _f.copyWith(sort: s)),
                            ),
                        ],
                      ),
                      title(locale.t('flt_categorias')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final c in ExpenseCategory.all)
                            FilterChip(
                              avatar: Icon(categoryIcon(c), size: 16, color: categoryColor(c)),
                              label: Text(locale.t(categoryLabelKey(c)), style: const TextStyle(fontSize: 12.5)),
                              selected: _f.categories.contains(c),
                              onSelected: (on) => setState(() {
                                final Set<String> next = {..._f.categories};
                                on ? next.add(c) : next.remove(c);
                                _f = _f.copyWith(categories: next);
                              }),
                            ),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        title(locale.t('flt_etiquetas')),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final t in tags)
                              FilterChip(
                                label: Text('#$t', style: const TextStyle(fontSize: 12.5)),
                                selected: _f.tags.contains(t),
                                onSelected: (on) => setState(() {
                                  final Set<String> next = {..._f.tags};
                                  on ? next.add(t) : next.remove(t);
                                  _f = _f.copyWith(tags: next);
                                }),
                              ),
                          ],
                        ),
                      ],
                      title(locale.t('flt_tipo')),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final k in ExpenseKindFilter.values)
                            ChoiceChip(
                              label: Text(_kindLabel(locale, k), style: const TextStyle(fontSize: 12.5)),
                              selected: _f.kind == k,
                              onSelected: (_) => setState(() => _f = _f.copyWith(kind: k)),
                            ),
                        ],
                      ),
                      if (finance.accounts.isNotEmpty) ...[
                        title(locale.t('flt_cuenta')),
                        DropdownButton<String?>(
                          value: _f.accountId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text(locale.t('flt_todas_cuentas'))),
                            for (final a in finance.accounts) DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
                          ],
                          onChanged: (v) => setState(() => _f = _f.copyWith(accountId: v, clearAccount: v == null)),
                        ),
                      ],
                      if (currencies.length > 1) ...[
                        title(locale.t('flt_moneda')),
                        DropdownButton<String?>(
                          value: _f.currency,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text(locale.t('flt_todas_monedas'))),
                            for (final c in currencies) DropdownMenuItem<String?>(value: c, child: Text(c)),
                          ],
                          onChanged: (v) => setState(() => _f = _f.copyWith(currency: v, clearCurrency: v == null)),
                        ),
                      ],
                      title('${locale.t('flt_monto')} (${finance.localCurrency})'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _min,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: locale.t('flt_desde')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _max,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: locale.t('flt_hasta')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: _clear, child: Text(locale.t('flt_limpiar')))),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: ElevatedButton(onPressed: _apply, child: Text(locale.t('flt_aplicar')))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
