import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../widgets/currency_dropdown.dart';
import '../widgets/section_card.dart';

enum ShippingMethod { air, express, custom }

/// Calculadora de envíos: compara el peso real con el peso volumétrico
/// (largo × ancho × alto ÷ divisor) y cobra el mayor de los dos. El
/// resultado se calcula en vivo y puede guardarse como gasto.
class ShippingCalculatorScreen extends StatefulWidget {
  const ShippingCalculatorScreen({super.key});

  @override
  State<ShippingCalculatorScreen> createState() => _ShippingCalculatorScreenState();
}

class _ShippingCalculatorScreenState extends State<ShippingCalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _boxesController = TextEditingController(text: '1');
  final TextEditingController _customDivisorController = TextEditingController(text: '5000');

  ShippingMethod _method = ShippingMethod.air;
  String? _rateCurrency;

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _rateController.dispose();
    _boxesController.dispose();
    _customDivisorController.dispose();
    super.dispose();
  }

  double _read(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  double get _divisor {
    switch (_method) {
      case ShippingMethod.air:
        return 5000;
      case ShippingMethod.express:
        return 6000;
      case ShippingMethod.custom:
        final double custom = _read(_customDivisorController);
        return custom > 0 ? custom : 5000;
    }
  }

  void _clear() {
    for (final c in [
      _weightController,
      _lengthController,
      _widthController,
      _heightController,
      _rateController,
    ]) {
      c.clear();
    }
    _boxesController.text = '1';
    setState(() => _method = ShippingMethod.air);
  }

  void _showInfo(LocaleProvider locale) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('envio_que_es_divisor')),
        content: Text(locale.t('envio_info_divisor')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cerrar')),
          ),
        ],
      ),
    );
  }

  void _saveAsExpense({
    required FinanceProvider finance,
    required LocaleProvider locale,
    required double cost,
    required String currency,
  }) {
    finance.addExpense(
      name: locale.t('envio_nombre_gasto'),
      amount: cost,
      currency: currency,
      category: ExpenseCategory.otros,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(locale.t('envio_guardado'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.watch<FinanceProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;

    final String rateCurrency = _rateCurrency ?? finance.localCurrency;

    final double weight = _read(_weightController);
    final double length = _read(_lengthController);
    final double width = _read(_widthController);
    final double height = _read(_heightController);
    final double rate = _read(_rateController);
    final int boxes = _read(_boxesController).round().clamp(1, 999).toInt();

    final double volumetric = (length * width * height) / _divisor;
    final double chargeable = weight > volumetric ? weight : volumetric;
    final bool chargedByVolume = volumetric > weight;
    final double cost = chargeable * rate * boxes;
    final bool hasResult = chargeable > 0;

    final bool showLocalEquivalent = cost > 0 &&
        rateCurrency != finance.localCurrency &&
        currencyProvider.canConvert(rateCurrency, finance.localCurrency);
    final double localEquivalent = showLocalEquivalent
        ? currencyProvider.convert(cost, rateCurrency, finance.localCurrency)
        : 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    locale.t('envios_titulo'),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: locale.t('limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: SectionLabel(locale.t('tipo_de_envio'))),
                      IconButton(
                        onPressed: () => _showInfo(locale),
                        icon: Icon(Icons.help_outline, size: 20, color: theme.colorScheme.primary),
                        tooltip: locale.t('envio_que_es_divisor'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ShippingMethod>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ShippingMethod.air,
                        label: Text('${locale.t('envio_aereo')}\n(5000)',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ShippingMethod.express,
                        label: Text('${locale.t('envio_express')}\n(6000)',
                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ShippingMethod.custom,
                        label: Text(locale.t('envio_otro'), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (selection) => setState(() => _method = selection.first),
                  ),
                  if (_method == ShippingMethod.custom) ...[
                    const SizedBox(height: 8),
                    _numberField(_customDivisorController, locale.t('envio_divisor_personalizado')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('envio_dimensiones')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: _numberField(_lengthController, locale.t('envio_largo'))),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_widthController, locale.t('envio_ancho'))),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_heightController, locale.t('envio_alto'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _numberField(_weightController, locale.t('envio_peso_real'))),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_boxesController, locale.t('envio_cajas'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(locale.t('envio_tarifa')),
                  Row(
                    children: [
                      Expanded(child: _numberField(_rateController, locale.t('envio_tarifa_por_kg'))),
                      const SizedBox(width: 12),
                      CurrencyDropdown(
                        value: rateCurrency,
                        dense: true,
                        onChanged: (value) => setState(() => _rateCurrency = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasResult)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(locale.t('envio_resultado')),
                    const SizedBox(height: 12),
                    _resultRow(theme, locale.t('envio_peso_real'), '${weight.toStringAsFixed(2)} kg'),
                    const SizedBox(height: 6),
                    _resultRow(theme, locale.t('envio_peso_volumetrico'), '${volumetric.toStringAsFixed(2)} kg'),
                    const Divider(height: 24),
                    _resultRow(
                      theme,
                      locale.t('envio_peso_a_cobrar'),
                      '${chargeable.toStringAsFixed(2)} kg',
                      bold: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chargedByVolume
                          ? locale.t('envio_cobra_por_volumen')
                          : locale.t('envio_cobra_por_peso'),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (cost > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: extras.cardAlt,
                          borderRadius: BorderRadius.circular((extras.cardRadius - 4).clamp(4.0, 100.0).toDouble()),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(locale.t('envio_costo_estimado'), style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatCurrency(cost, rateCurrency),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (showLocalEquivalent)
                              Text(
                                '≈ ${formatCurrency(localEquivalent, finance.localCurrency)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            if (boxes > 1)
                              Text(
                                '$boxes × ${formatCurrency(cost / boxes, rateCurrency)}',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _saveAsExpense(
                          finance: finance,
                          locale: locale,
                          cost: cost,
                          currency: rateCurrency,
                        ),
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: Text(locale.t('envio_guardar_como_gasto')),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _resultRow(ThemeData theme, String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : null)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w600),
        ),
      ],
    );
  }
}
