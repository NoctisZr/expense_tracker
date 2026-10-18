import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../services/backup_service.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';

/// Tasas manuales: fijar, por ejemplo, el dólar paralelo de ARS o VES.
Future<void> showManualRatesDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _ManualRatesDialog());
}

class _ManualRatesDialog extends StatefulWidget {
  const _ManualRatesDialog();

  @override
  State<_ManualRatesDialog> createState() => _ManualRatesDialogState();
}

class _ManualRatesDialogState extends State<_ManualRatesDialog> {
  final TextEditingController _rateController = TextEditingController();
  String _code = 'ARS';

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double? value =
        double.tryParse(_rateController.text.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    await context.read<CurrencyProvider>().setManualRate(_code, value);
    _rateController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final currency = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final double? apiRate = currency.apiRateFor(_code);

    return AlertDialog(
      title: Text(locale.t('tasas_manuales')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locale.t('tasas_manuales_ayuda'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('1 USD ='),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: apiRate == null ? null : apiRate.toStringAsFixed(2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CurrencyDropdown(
                  value: _code,
                  dense: true,
                  onChanged: (value) => setState(() => _code = value),
                ),
              ],
            ),
            if (apiRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${locale.t('tasa_automatica')}: ${apiRate.toStringAsFixed(4)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
            ),
            if (currency.manualRates.isNotEmpty) ...[
              const Divider(height: 24),
              Text(locale.t('tasas_manuales_activas'),
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              for (final entry in currency.manualRates.entries)
                Row(
                  children: [
                    Expanded(child: Text('1 USD = ${entry.value} ${entry.key}')),
                    IconButton(
                      onPressed: () => currency.clearManualRate(entry.key),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: locale.t('quitar_tasa_manual'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cerrar')),
        ),
      ],
    );
  }
}

/// Elegir cómo importar un respaldo: reemplazar todo o fusionar.
/// Devuelve `true` = fusionar, `false` = reemplazar, `null` = cancelar.
Future<bool?> askImportMode(BuildContext context) {
  final locale = context.read<LocaleProvider>();
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(locale.t('importar_modo_titulo')),
      content: Text(locale.t('importar_modo_mensaje')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(locale.t('cancelar')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(locale.t('importar_reemplazar')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(locale.t('importar_fusionar')),
        ),
      ],
    ),
  );
}

/// Lista de respaldos automáticos del espacio activo para restaurarlos.
Future<void> showAutoBackupsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AutoBackupsSheet(),
  );
}

class _AutoBackupsSheet extends StatefulWidget {
  const _AutoBackupsSheet();

  @override
  State<_AutoBackupsSheet> createState() => _AutoBackupsSheetState();
}

class _AutoBackupsSheetState extends State<_AutoBackupsSheet> {
  final BackupService _service = BackupService();
  late Future<List<File>> _files;

  @override
  void initState() {
    super.initState();
    _files = _service.listAutoBackups(context.read<FinanceProvider>().activeWorkspaceId);
  }

  DateTime? _dateOf(File file) {
    // auto_<espacio>_<2026-10-16T08-03-38>.json
    final String name = file.path.split('/').last.replaceFirst('.json', '');
    final String stamp = name.split('_').last;
    final int t = stamp.indexOf('T');
    if (t == -1) return null;
    final String fixed = '${stamp.substring(0, t)}T${stamp.substring(t + 1).replaceAll('-', ':')}';
    return DateTime.tryParse(fixed);
  }

  Future<void> _restore(File file) async {
    final locale = context.read<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('restaurar_respaldo_titulo')),
        content: Text(locale.t('restaurar_respaldo_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(locale.t('confirmar')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final Map<String, dynamic> data = await _service.readBackupFile(file);
      await finance.importData(data);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(locale.t('importacion_exitosa'))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(locale.t('error_importar'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locale.t('respaldos_automaticos'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(locale.t('respaldos_automaticos_ayuda'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<File>>(
                future: _files,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<File> files = snapshot.data!;
                  if (files.isEmpty) {
                    return Text(locale.t('sin_respaldos_automaticos'),
                        style: TextStyle(color: theme.hintColor));
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final file in files)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(
                            _dateOf(file) == null ? file.path.split('/').last : formatDateTime(_dateOf(file)!),
                          ),
                          trailing: TextButton(
                            onPressed: () => _restore(file),
                            child: Text(locale.t('restaurar')),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elegir el mes del reporte (los últimos 12). Devuelve el primer día del
/// mes elegido o `null` si se cancela.
Future<DateTime?> pickReportMonth(BuildContext context) {
  final locale = context.read<LocaleProvider>();
  final DateTime now = DateTime.now();
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(locale.t('elige_mes')),
      children: [
        for (int back = 0; back < 12; back++)
          Builder(builder: (_) {
            final DateTime month = DateTime(now.year, now.month - back, 1);
            return SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(month),
              child: Text('${month.month.toString().padLeft(2, '0')}/${month.year}'),
            );
          }),
      ],
    ),
  );
}


/// Activar tasas actualizadas cada hora con una clave GRATIS de Open Exchange
/// Rates (el plan gratuito permite 1 000 consultas al mes).
Future<void> showHourlyRatesDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _HourlyRatesDialog());
}

class _HourlyRatesDialog extends StatefulWidget {
  const _HourlyRatesDialog();

  @override
  State<_HourlyRatesDialog> createState() => _HourlyRatesDialogState();
}

class _HourlyRatesDialogState extends State<_HourlyRatesDialog> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<CurrencyProvider>().openExchangeAppId ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currency = context.read<CurrencyProvider>();
    final locale = context.read<LocaleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    await currency.setOpenExchangeAppId(_controller.text);
    if (!currency.hasHourlyKey) {
      navigator.pop();
      return;
    }
    final RatesRefreshOutcome outcome = await currency.fetchRates(manual: true, force: true);
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(outcome == RatesRefreshOutcome.failed
          ? '${locale.t('tasas_clave_error')}: ${currency.errorMessage ?? ''}'
          : locale.t('tasas_clave_guardada')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(locale.t('tasas_cada_hora')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locale.t('tasas_cada_hora_ayuda'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            const SelectableText('openexchangerates.org', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: locale.t('tasas_clave_label')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        if (context.read<CurrencyProvider>().hasHourlyKey)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    await context.read<CurrencyProvider>().setOpenExchangeAppId(null);
                    navigator.pop();
                  },
            child: Text(locale.t('tasas_clave_quitar')),
          ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
