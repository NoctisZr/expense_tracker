import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/couple_models.dart';
import '../providers/couple_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/couple_crypto.dart';
import '../utils/formatters.dart';
import 'couple_tutorial.dart';
import 'section_card.dart';

String _errorText(LocaleProvider l, CoupleError e) {
  switch (e) {
    case CoupleError.network:
      return l.t('pa_err_red');
    case CoupleError.invalidCode:
      return l.t('pa_err_codigo');
    case CoupleError.notFound:
      return l.t('pa_err_no_existe');
    case CoupleError.full:
      return l.t('pa_err_lleno');
    default:
      return l.t('pa_err_otro');
  }
}

String _approx(double amount, String currency, CurrencyProvider cp, String local) {
  if (currency.isEmpty || currency == local || !cp.canConvert(currency, local)) return '';
  return '≈ ${formatCurrency(cp.convert(amount, currency, local), local)}';
}

/// Pestaña «Pareja»: un apartado aparte donde cada persona ve lo que la otra
/// decide compartir. Nada de esto se mezcla con tus propios datos.
class CoupleView extends StatefulWidget {
  const CoupleView({super.key});

  @override
  State<CoupleView> createState() => _CoupleViewState();
}

class _CoupleViewState extends State<CoupleView> {
  Timer? _timer;
  int _tab = 0; // 0 Saldo, 1 Su actividad, 2 Lo que comparto
  String _filter = 'expenses';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    _timer = Timer.periodic(const Duration(seconds: 90), (_) => _sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final couple = context.read<CoupleProvider>();
    if (couple.isLinked) couple.syncNow(context.read<FinanceProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final couple = context.watch<CoupleProvider>();
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    if (!couple.isConfigured) {
      return SectionCard(child: Text(locale.t('pa_no_config'), style: TextStyle(color: theme.hintColor)));
    }
    if (!couple.isLinked) return _Intro(couple: couple, locale: locale);

    if (couple.workspaceId != finance.activeWorkspaceId) {
      final String wsName = finance.workspaces
          .firstWhere((w) => w.id == couple.workspaceId, orElse: () => finance.activeWorkspace)
          .name;
      return SectionCard(
        child: Text(locale.t('pa_otro_espacio').replaceAll('{w}', wsName)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(couple: couple, locale: locale),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(locale.t('pa_tab_saldo'), style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 1, label: Text(locale.t('pa_tab_actividad'), style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 2, label: Text(locale.t('pa_tab_mio'), style: const TextStyle(fontSize: 12))),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 12),
        if (_tab == 0) _BalanceTab(couple: couple, locale: locale),
        if (_tab == 1)
          _ActivityTab(
            couple: couple,
            locale: locale,
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
        if (_tab == 2) _MineTab(couple: couple, locale: locale),
      ],
    );
  }
}

// ---------------------------------------------------------------- activar
class _Intro extends StatelessWidget {
  final CoupleProvider couple;
  final LocaleProvider locale;
  const _Intro({required this.couple, required this.locale});

  Future<void> _activate(BuildContext context) async {
    if (!couple.tutorialDone) {
      await showCoupleTutorial(context);
      couple.markTutorialDone();
    }
    if (!context.mounted) return;
    await showDialog<void>(context: context, builder: (_) => const _SetupDialog());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locale.t('pa_intro_titulo'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          point(Icons.person_outline_rounded, locale.t('pa_intro_1')),
          point(Icons.visibility_outlined, locale.t('pa_intro_2')),
          point(Icons.call_split_rounded, locale.t('pa_intro_3')),
          point(Icons.lock_outline_rounded, locale.t('pa_intro_4')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _activate(context),
              icon: const Icon(Icons.favorite_border_rounded),
              label: Text(locale.t('pa_activar')),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => showCoupleTutorial(context),
              child: Text(locale.t('pa_ver_tutorial')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupDialog extends StatefulWidget {
  const _SetupDialog();

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _join = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = context.read<CoupleProvider>().displayName;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final locale = context.read<LocaleProvider>();
    final couple = context.read<CoupleProvider>();
    final finance = context.read<FinanceProvider>();
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = locale.t('pa_err_nombre'));
      return;
    }
    if (_join && !isValidInviteCode(_code.text)) {
      setState(() => _error = locale.t('pa_err_codigo'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_join) {
        await couple.joinCouple(code: _code.text, name: name, finance: finance);
      } else {
        await couple.createCouple(name: name, finance: finance);
      }
      if (mounted) Navigator.of(context).pop();
    } on CoupleException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorText(locale, e.error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(locale.t('pa_activar')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: locale.t('pa_tu_nombre')),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(locale.t('pa_crear'), style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: true, label: Text(locale.t('pa_unirme'), style: const TextStyle(fontSize: 12))),
                ],
                selected: {_join},
                onSelectionChanged: _busy ? null : (s) => setState(() => _join = s.first),
              ),
            ),
            const SizedBox(height: 10),
            if (_join)
              TextField(
                controller: _code,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: locale.t('pa_codigo_label'),
                  helperText: locale.t('pa_codigo_ayuda'),
                  helperMaxLines: 2,
                ),
              )
            else
              Text(locale.t('pa_crear_ayuda'), style: theme.textTheme.bodySmall),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_busy) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(locale.t('pa_conectando')),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _busy ? null : _continue, child: Text(locale.t('pa_continuar'))),
      ],
    );
  }
}

// -------------------------------------------------------------- cabecera
class _HeaderCard extends StatelessWidget {
  final CoupleProvider couple;
  final LocaleProvider locale;
  const _HeaderCard({required this.couple, required this.locale});

  String _status() {
    if (couple.syncing) return locale.t('pa_sincronizando');
    if (couple.lastError != null) return _errorText(locale, couple.lastError!);
    final DateTime? last = couple.lastSync;
    if (last == null) return locale.t('pa_sin_sync');
    final String hh = last.hour.toString().padLeft(2, '0');
    final String mm = last.minute.toString().padLeft(2, '0');
    return '${locale.t('pa_ultima_sync')}: $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String me = couple.displayName.isEmpty ? locale.t('pa_tu') : couple.displayName;
    final String other = couple.partner.name ?? locale.t('pa_tu_pareja');
    final String? code = couple.inviteCode;
    final FinanceProvider finance = context.read<FinanceProvider>();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$me  +  $other',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              couple.syncing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      onPressed: () => couple.syncNow(finance),
                      icon: Icon(Icons.sync_rounded, color: theme.colorScheme.primary),
                      tooltip: locale.t('pa_sincronizar'),
                      visualDensity: VisualDensity.compact,
                    ),
            ],
          ),
          Text(
            _status(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: couple.lastError != null ? theme.colorScheme.error : theme.hintColor,
            ),
          ),
          if (!couple.hasPartner && code != null) ...[
            const Divider(height: 22),
            Text(locale.t('pa_esperando'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      formatInviteCode(code),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: formatInviteCode(code)));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('pa_copiado'))));
                  },
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: locale.t('pa_copiar'),
                ),
                IconButton(
                  onPressed: () => Share.share(
                    locale.t('pa_mensaje_invitacion').replaceAll('{code}', formatInviteCode(code)),
                  ),
                  icon: const Icon(Icons.share_rounded),
                  tooltip: locale.t('pa_compartir'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- saldo
class _BalanceTab extends StatelessWidget {
  final CoupleProvider couple;
  final LocaleProvider locale;
  const _BalanceTab({required this.couple, required this.locale});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final String local = finance.localCurrency;
    final double balance = couple.balanceLocal(finance, currency);
    final String other = couple.partner.name ?? locale.t('pa_tu_pareja');

    final List<_SplitRow> splits = [
      for (final e in finance.sharedExpenses)
        _SplitRow(
          name: e.name,
          date: e.date,
          total: e.sharedTotal ?? e.amount,
          part: e.amount,
          currency: e.currency,
          paidByMe: e.paidByCreator,
          mine: true,
        ),
      for (final e in couple.partner.splits)
        _SplitRow(
          name: e.name,
          date: e.date,
          total: e.total,
          part: e.amount,
          currency: e.currency,
          paidByMe: !e.paidByAuthor,
          mine: false,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    String headline;
    Color? color;
    if (balance > 0.004) {
      headline = locale.t('pa_te_debe').replaceAll('{n}', other);
      color = theme.colorScheme.primary;
    } else if (balance < -0.004) {
      headline = locale.t('pa_le_debes').replaceAll('{n}', other);
      color = theme.colorScheme.error;
    } else {
      headline = locale.t('pareja_a_mano');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(locale.t('pa_saldo_titulo')),
              const SizedBox(height: 6),
              Text(headline, style: theme.textTheme.bodyLarge),
              if (balance.abs() > 0.004)
                Text(
                  formatCurrency(balance.abs(), local),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _SettleDialog(balance: balance),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(locale.t('pa_saldar')),
                ),
              ),
              const SizedBox(height: 8),
              Text(locale.t('pa_nota_monedas'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(locale.t('pa_divididos')),
              const SizedBox(height: 6),
              if (splits.isEmpty)
                Text(locale.t('pa_sin_divididos'), style: TextStyle(color: theme.hintColor))
              else
                for (final s in splits.take(30))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.call_split_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                '${formatDateShort(s.date)} · ${s.mine ? locale.t('pa_tu') : other} · '
                                '${s.paidByMe ? locale.t('quien_pago_yo') : locale.t('quien_pago_pareja')}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCurrency(s.total, s.currency),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${s.mine ? locale.t('mi_parte') : locale.t('pa_su_parte')} ${formatAmount(s.part)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        if (couple.mySettlements.isNotEmpty || couple.partner.settlements.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(locale.t('pa_pagos')),
                const SizedBox(height: 6),
                for (final s in couple.mySettlements.reversed.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${s['pp'] == true ? locale.t('pa_pago_yo') : locale.t('pa_pago_el')} · '
                      '${formatCurrency((s['a'] as num).toDouble(), s['c'].toString())}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                for (final s in couple.partner.settlements.take(10))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${s.paidByAuthor ? locale.t('pa_pago_el_a_mi') : locale.t('pa_pago_yo_a_el')} · '
                      '${formatCurrency(s.amount, s.currency)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SplitRow {
  final String name;
  final DateTime date;
  final double total;
  final double part;
  final String currency;
  final bool paidByMe;
  final bool mine;
  const _SplitRow({
    required this.name,
    required this.date,
    required this.total,
    required this.part,
    required this.currency,
    required this.paidByMe,
    required this.mine,
  });
}

class _SettleDialog extends StatefulWidget {
  final double balance;
  const _SettleDialog({required this.balance});

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  late final TextEditingController _amount;
  late bool _iPaid;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.balance.abs() > 0.004 ? widget.balance.abs().toStringAsFixed(2) : '',
    );
    // Si le debo, lo normal es que yo pague.
    _iPaid = widget.balance < 0;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    return AlertDialog(
      title: Text(locale.t('pa_saldar_titulo')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(locale.t('pa_yo_pague'), style: const TextStyle(fontSize: 12))),
                ButtonSegment(value: false, label: Text(locale.t('pa_me_pago'), style: const TextStyle(fontSize: 12))),
              ],
              selected: {_iPaid},
              onSelectionChanged: (s) => setState(() => _iPaid = s.first),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${locale.t('monto')} (${finance.localCurrency})'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(
          onPressed: () {
            final double? value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
            if (value == null || value <= 0) return;
            context.read<CoupleProvider>().recordSettlement(
                  amount: value,
                  currency: finance.localCurrency,
                  iPaid: _iPaid,
                  finance: finance,
                );
            Navigator.of(context).pop();
          },
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- actividad
class _ActivityTab extends StatelessWidget {
  final CoupleProvider couple;
  final LocaleProvider locale;
  final String filter;
  final ValueChanged<String> onFilter;
  const _ActivityTab({required this.couple, required this.locale, required this.filter, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final PartnerData p = couple.partner;
    final String local = finance.localCurrency;
    final String other = p.name ?? locale.t('pa_tu_pareja');
    final DateTime now = DateTime.now();
    bool thisMonth(DateTime d) => d.year == now.year && d.month == now.month;

    if (!p.hasAnything) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_empty_rounded, color: theme.hintColor),
            const SizedBox(height: 8),
            Text(locale.t('pa_nada_aun').replaceAll('{n}', other)),
          ],
        ),
      );
    }

    final List<PExpense> allExpenses = [...p.expenses, ...p.splits]..sort((a, b) => b.date.compareTo(a.date));

    // Totales del mes por moneda (se muestran en la moneda de tu pareja).
    Map<String, double> sums(Iterable<(double, String)> items) {
      final Map<String, double> out = {};
      for (final (double a, String c) in items) {
        out[c] = (out[c] ?? 0) + a;
      }
      return out;
    }

    Widget summaryLine(String label, Map<String, double> byCurrency) {
      if (byCurrency.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$label:', style: theme.textTheme.bodyMedium),
            for (final e in byCurrency.entries)
              Text(
                '${formatCurrency(e.value, e.key)} ${_approx(e.value, e.key, currency, local)}'.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      );
    }

    final Map<String, double> spentMonth = sums([
      for (final e in allExpenses)
        if (thisMonth(e.date)) (e.amount, e.currency),
    ]);
    final Map<String, double> incomeMonth = sums([
      for (final i in p.incomes)
        if (thisMonth(i.date)) (i.amount, i.currency),
    ]);

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required String amount,
      String approx = '',
      Color? amountColor,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: amountColor)),
                  if (approx.isNotEmpty) Text(approx, style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        );

    Widget content;
    switch (filter) {
      case 'incomes':
        content = p.incomes.isEmpty
            ? Text(locale.t('pa_no_comparte').replaceAll('{n}', other), style: TextStyle(color: theme.hintColor))
            : Column(children: [
                for (final i in p.incomes.take(50))
                  row(
                    icon: Icons.south_west_rounded,
                    title: i.label,
                    subtitle: formatDateShort(i.date),
                    amount: '+${formatCurrency(i.amount, i.currency)}',
                    approx: _approx(i.amount, i.currency, currency, local),
                    amountColor: theme.colorScheme.primary,
                  ),
              ]);
        break;
      case 'vaults':
        content = p.vaults.isEmpty
            ? Text(locale.t('pa_no_comparte').replaceAll('{n}', other), style: TextStyle(color: theme.hintColor))
            : Column(children: [
                for (final v in p.vaults)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${(v.progress * 100).round()} %'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: v.progress,
                          minHeight: 7,
                          semanticsLabel: '${v.name} ${(v.progress * 100).round()} %',
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${formatCurrency(v.current, v.currency)} / ${formatCurrency(v.target, v.currency)} '
                          '${_approx(v.current, v.currency, currency, local)}'.trim(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ]);
        break;
      case 'debts':
        content = p.debts.isEmpty
            ? Text(locale.t('pa_no_comparte').replaceAll('{n}', other), style: TextStyle(color: theme.hintColor))
            : Column(children: [
                for (final d in p.debts.take(50))
                  row(
                    icon: d.paid ? Icons.check_circle_outline_rounded : Icons.account_balance_wallet_outlined,
                    title: d.person,
                    subtitle: '${formatDateShort(d.date)} · '
                        '${d.owedToAuthor ? locale.t('pa_deuda_le_deben') : locale.t('pa_deuda_debe')}'
                        '${d.paid ? ' · ${locale.t('pa_pagada')}' : ''}',
                    amount: formatCurrency(d.amount, d.currency),
                    approx: _approx(d.amount, d.currency, currency, local),
                  ),
              ]);
        break;
      default:
        content = allExpenses.isEmpty
            ? Text(locale.t('pa_no_comparte').replaceAll('{n}', other), style: TextStyle(color: theme.hintColor))
            : Column(children: [
                for (final e in allExpenses.take(50))
                  row(
                    icon: e.split ? Icons.call_split_rounded : Icons.receipt_long_rounded,
                    title: e.name,
                    subtitle: '${locale.t(categoryLabelKey(e.category))} · ${formatDateShort(e.date)}'
                        '${e.split ? ' · ${locale.t('total_cuenta')} ${formatAmount(e.total)}' : ''}',
                    amount: '-${formatCurrency(e.amount, e.currency)}',
                    approx: _approx(e.amount, e.currency, currency, local),
                  ),
              ]);
    }

    Widget chip(String value, String label) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: filter == value,
          onSelected: (_) => onFilter(value),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel('${locale.t('pa_este_mes')} · $other'),
              const SizedBox(height: 4),
              summaryLine(locale.t('pa_gastado'), spentMonth),
              summaryLine(locale.t('pa_ingresado'), incomeMonth),
              if (spentMonth.isEmpty && incomeMonth.isEmpty)
                Text(locale.t('pa_sin_datos_mes'), style: TextStyle(color: theme.hintColor)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  chip('expenses', locale.t('pa_f_gastos')),
                  chip('incomes', locale.t('pa_f_ingresos')),
                  chip('vaults', locale.t('pa_f_metas')),
                  chip('debts', locale.t('pa_f_deudas')),
                ],
              ),
              const SizedBox(height: 8),
              content,
              const SizedBox(height: 6),
              Text(locale.t('pa_solo_lectura'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- lo que comparto
class _MineTab extends StatelessWidget {
  final CoupleProvider couple;
  final LocaleProvider locale;
  const _MineTab({required this.couple, required this.locale});

  Future<void> _editName(BuildContext context) async {
    final finance = context.read<FinanceProvider>();
    final TextEditingController controller = TextEditingController(text: couple.displayName);
    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('pa_tu_nombre')),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(locale.t('cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(locale.t('guardar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) await couple.setDisplayName(result, finance);
  }

  Future<void> _leave(BuildContext context) async {
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('pa_desvincular')),
        content: Text(locale.t('pa_desvincular_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(locale.t('cancelar'))),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(locale.t('pa_desvincular_btn')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await couple.leave(finance);
    } on CoupleException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_errorText(locale, e.error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceProvider>();
    final theme = Theme.of(context);
    final CouplePrefs prefs = couple.prefs;
    final String? code = couple.inviteCode;

    Widget toggle(String key, bool value, String title, String subtitle) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          value: value,
          onChanged: (v) => couple.setShare(key, v, finance),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(locale.t('pa_comparto_titulo')),
              const SizedBox(height: 4),
              Text(locale.t('pa_comparto_ayuda'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              toggle('expenses', prefs.expenses, locale.t('pa_sw_gastos'), locale.t('pa_sw_gastos_d')),
              toggle('incomes', prefs.incomes, locale.t('pa_sw_ingresos'), locale.t('pa_sw_ingresos_d')),
              toggle('vaults', prefs.vaults, locale.t('pa_sw_metas'), locale.t('pa_sw_metas_d')),
              toggle('debts', prefs.debts, locale.t('pa_sw_deudas'), locale.t('pa_sw_deudas_d')),
              const Divider(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.call_split_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(locale.t('pa_siempre'), style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(locale.t('pa_tu_nombre')),
                subtitle: Text(couple.displayName.isEmpty ? '-' : couple.displayName),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editName(context),
              ),
              if (code != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(locale.t('pa_mi_codigo')),
                  subtitle: Text(formatInviteCode(code), style: const TextStyle(letterSpacing: 1.5)),
                  trailing: const Icon(Icons.copy_rounded),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: formatInviteCode(code)));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('pa_copiado'))));
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(locale.t('pa_ver_tutorial')),
                trailing: const Icon(Icons.help_outline_rounded),
                onTap: () => showCoupleTutorial(context),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(locale.t('pa_privacidad'), style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => _leave(context),
            icon: Icon(Icons.link_off_rounded, color: theme.colorScheme.error),
            label: Text(locale.t('pa_desvincular'), style: TextStyle(color: theme.colorScheme.error)),
          ),
        ),
      ],
    );
  }
}
