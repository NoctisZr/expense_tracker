import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../widgets/currency_dropdown.dart';
import '../widgets/section_card.dart';

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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatesStatusBanner extends StatelessWidget {
  final CurrencyProvider currencyProvider;
  final LocaleProvider locale;

  const _RatesStatusBanner({required this.currencyProvider, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String message;
    IconData icon = Icons.history;
    Color? iconColor;

    if (currencyProvider.isLoading && !currencyProvider.hasRates) {
      message = locale.t('cargando_tasas');
    } else if (currencyProvider.errorMessage != null) {
      message = currencyProvider.hasRates
          ? locale.t('sin_conexion_tasas')
          : locale.t('sin_tasas_disponibles');
      icon = Icons.cloud_off_rounded;
      iconColor = theme.colorScheme.error;
    } else if (currencyProvider.lastUpdated != null) {
      message =
          '${locale.t('ultima_actualizacion_tasas')}: ${formatDateTime(currencyProvider.lastUpdated!)}';
    } else {
      message = locale.t('sin_tasas_disponibles');
    }

    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (currencyProvider.isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            )
          else
            Icon(icon, size: 20, color: iconColor ?? theme.hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.hintColor, fontSize: 12.5),
            ),
          ),
          IconButton(
            onPressed: currencyProvider.isLoading ? null : () => currencyProvider.fetchRates(),
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
            tooltip: locale.t('actualizar_tasas'),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
