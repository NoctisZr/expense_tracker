import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../widgets/currency_dropdown.dart';
import 'rate_chart_screen.dart';
import '../widgets/section_card.dart';
import '../widgets/settings_dialogs.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _spreadController =
      TextEditingController(text: '3.0');
  late String _from;
  late String _to;
  bool _applySpread = false;

  @override
  void initState() {
    super.initState();
    final String localCurrency = context.read<FinanceProvider>().localCurrency;
    _from = 'USD';
    _to = localCurrency == 'USD' ? 'BRL' : localCurrency;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _spreadController.dispose();
    super.dispose();
  }

  void _swap() {
    setState(() {
      final String temp = _from;
      _from = _to;
      _to = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final double amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0;
    final double baseRate = currencyProvider.rateBetween(_from, _to);
    double result = amount * baseRate;

    final double spreadPercent =
        double.tryParse(_spreadController.text.trim().replaceAll(',', '.')) ?? 0;
    if (_applySpread && spreadPercent > 0) {
      result = result * (1 - spreadPercent / 100);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RatesStatusBanner(currencyProvider: currencyProvider, locale: locale),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('conversor_rapido')),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(labelText: locale.t('monto_a_cambiar')),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: CurrencyDropdown(
                            value: _from,
                            onChanged: (value) => setState(() => _from = value),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _swap,
                        icon: Icon(Icons.swap_horiz, color: theme.colorScheme.primary),
                        iconSize: 28,
                      ),
                      Expanded(
                        child: Center(
                          child: CurrencyDropdown(
                            value: _to,
                            onChanged: (value) => setState(() => _to = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: theme.extension<AppThemeExtras>()!.borderWidth,
                      ),
                      borderRadius: BorderRadius.circular(
                        (theme.extension<AppThemeExtras>()!.cardRadius - 4).clamp(4, 100).toDouble(),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _applySpread,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (value) => setState(() => _applySpread = value ?? false),
                        ),
                        Expanded(
                          child: Text(locale.t('aplicar_spread'), style: theme.textTheme.bodyMedium),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _spreadController,
                            enabled: _applySpread,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: locale.t('comision_bancaria'),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (currencyProvider.hasRates)
                    Text(
                      '1 $_from = ${formatAmount(baseRate)} $_to',
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCurrency(result, _to),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (currencyProvider.hasRates)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => RateChartScreen(from: _from, to: _to)),
                        ),
                        icon: const Icon(Icons.show_chart_rounded, size: 18),
                        label: Text(locale.t('ver_evolucion')),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra compacta de estado de las tasas: una línea con el estado y la hora
/// de la última descarga, y una segunda línea pequeña con la fecha del
/// proveedor. El detalle y la explicación viven en el botón de información.
class _RatesStatusBanner extends StatelessWidget {
  final CurrencyProvider currencyProvider;
  final LocaleProvider locale;

  const _RatesStatusBanner({required this.currencyProvider, required this.locale});

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _hhmm(DateTime when) => '${_two(when.hour)}:${_two(when.minute)}';

  /// "hace un momento", "hace 12 min", "hoy a las 16:32" o "17/10 16:32".
  String _ago(DateTime when) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(when);
    if (diff.inMinutes < 1) return locale.t('tasas_hace_un_momento');
    if (diff.inMinutes < 60) {
      return locale.t('tasas_hace_minutos').replaceAll('{n}', '${diff.inMinutes}');
    }
    final bool sameDay = when.year == now.year && when.month == now.month && when.day == now.day;
    if (sameDay) return '${locale.t('tasas_hoy_a_las')} ${_hhmm(when)}';
    return '${_two(when.day)}/${_two(when.month)} ${_hhmm(when)}';
  }

  Future<void> _refresh(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final RatesRefreshOutcome outcome = await currencyProvider.fetchRates(manual: true);
    final String key = switch (outcome) {
      RatesRefreshOutcome.updated => 'tasas_actualizadas_ok',
      RatesRefreshOutcome.unchanged => currencyProvider.hasHourlyKey
          ? 'tasas_sin_cambios_hora'
          : 'tasas_sin_cambios',
      RatesRefreshOutcome.skipped => 'tasas_espera',
      RatesRefreshOutcome.failed => 'tasas_fallo',
    };
    messenger.showSnackBar(SnackBar(content: Text(locale.t(key))));
  }

  void _showInfo(BuildContext context) {
    final rates = currencyProvider;
    final theme = Theme.of(context);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('tasas_info_titulo')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rates.lastUpdated != null)
                row(locale.t('tasas_datos_proveedor'), formatDateTime(rates.lastUpdated!)),
              if (rates.lastFetchedAt != null)
                row(locale.t('tasas_descargadas'), formatDateTime(rates.lastFetchedAt!)),
              if (rates.source != null) row(locale.t('tasas_fuente'), rates.source!),
              if (rates.errorMessage != null)
                row(locale.t('tasas_usando_guardadas'), rates.errorMessage!),
              const Divider(height: 20),
              Text(
                rates.hasHourlyKey ? locale.t('tasas_cada_hora_activa') : locale.t('tasas_una_vez_al_dia'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(locale.t('tasas_info_hora_local'), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          if (!rates.hasHourlyKey)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showHourlyRatesDialog(context);
              },
              child: Text(locale.t('tasas_cada_hora')),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cerrar')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final CurrencyProvider rates = currencyProvider;

    String title;
    String? subtitle;
    IconData icon = Icons.cloud_done_outlined;
    Color iconColor = theme.colorScheme.primary;

    if (rates.isLoading) {
      title = locale.t('tasas_actualizando');
    } else if (rates.hasRates) {
      if (rates.errorMessage != null) {
        title = locale.t('tasas_sin_conexion_corto');
        icon = Icons.cloud_off_rounded;
        iconColor = theme.colorScheme.error;
      } else if (rates.isStale) {
        title = locale.t('tasas_desactualizadas_corto');
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
      } else {
        title = rates.lastFetchedAt != null
            ? '${locale.t('tasas_actualizadas')} · ${_ago(rates.lastFetchedAt!)}'
            : locale.t('tasas_actualizadas');
      }
      if (rates.lastUpdated != null) {
        final DateTime u = rates.lastUpdated!;
        final String source = rates.source == null ? '' : ' · ${rates.source}';
        subtitle = '${locale.t('tasas_proveedor_corto')}: ${_two(u.day)}/${_two(u.month)} ${_hhmm(u)}$source';
      }
    } else {
      title = locale.t('sin_tasas_disponibles');
      subtitle = rates.errorMessage;
      icon = Icons.cloud_off_rounded;
      iconColor = theme.colorScheme.error;
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          if (rates.isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            )
          else
            Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showInfo(context),
            icon: Icon(Icons.info_outline_rounded, size: 20, color: theme.hintColor),
            tooltip: locale.t('tasas_info_titulo'),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: rates.isLoading ? null : () => _refresh(context),
            icon: Icon(Icons.refresh, size: 22, color: theme.colorScheme.primary),
            tooltip: locale.t('actualizar_tasas'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
