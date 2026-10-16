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

const double _kgPerLb = 0.45359237;
const double _cmPerInch = 2.54;

/// Calculadora de envíos: compara el peso real con el peso volumétrico
/// (largo × ancho × alto ÷ divisor) y cobra el mayor de los dos. Admite
/// cm/kg o pulgadas/libras, impuestos de aduana y cargos extra, y tarifas
/// guardadas por courier. El resultado se calcula en vivo y puede
/// guardarse como gasto.
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
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _extraController = TextEditingController();
  final TextEditingController _customDivisorController = TextEditingController(text: '5000');

  ShippingMethod _method = ShippingMethod.air;
  bool _imperial = false;
  String? _rateCurrency;

  @override
  void dispose() {
    for (final c in [
      _weightController,
      _lengthController,
      _widthController,
      _heightController,
      _rateController,
      _boxesController,
      _taxController,
      _extraController,
      _customDivisorController,
    ]) {
      c.dispose();
    }
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

  String get _methodKey => _method.name;

  void _clear() {
    for (final c in [
      _weightController,
      _lengthController,
      _widthController,
      _heightController,
      _rateController,
      _taxController,
      _extraController,
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

  // ---- Tarifas guardadas ------------------------------------------------

  Future<void> _savePreset(FinanceProvider finance, LocaleProvider locale, String currency) async {
    final double rateInput = _read(_rateController);
    if (rateInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('envio_tarifa_requerida'))),
      );
      return;
    }
    final TextEditingController nameController = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('envio_guardar_tarifa')),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: locale.t('envio_nombre_courier')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
            child: Text(locale.t('guardar')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    // La tarifa se guarda normalizada "por kg" para que sirva con cualquier unidad.
    final double ratePerKg = _imperial ? rateInput / _kgPerLb : rateInput;
    final List<Map<String, dynamic>> presets = finance.shippingPresets
      ..removeWhere((p) => p['name'] == name)
      ..add({
        'name': name,
        'rate': ratePerKg,
        'currency': currency,
        'method': _methodKey,
        'divisor': _read(_customDivisorController),
      });
    finance.saveShippingPresets(presets);
  }

  void _applyPreset(Map<String, dynamic> preset) {
    final double ratePerKg = (preset['rate'] as num).toDouble();
    final double shown = _imperial ? ratePerKg * _kgPerLb : ratePerKg;
    setState(() {
      _rateController.text = shown.toStringAsFixed(2);
      _rateCurrency = preset['currency'] as String?;
      final String? method = preset['method'] as String?;
      _method = ShippingMethod.values.firstWhere(
        (m) => m.name == method,
        orElse: () => ShippingMethod.air,
      );
      final num? divisor = preset['divisor'] as num?;
      if (_method == ShippingMethod.custom && divisor != null && divisor > 0) {
        _customDivisorController.text = divisor.toString();
      }
    });
  }

  void _deletePreset(FinanceProvider finance, Map<String, dynamic> preset) {
    final List<Map<String, dynamic>> presets = finance.shippingPresets
      ..removeWhere((p) => p['name'] == preset['name']);
    finance.saveShippingPresets(presets);
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
    final String weightUnit = _imperial ? 'lb' : 'kg';
    final String lengthUnit = _imperial ? 'in' : 'cm';

    // Todo se calcula internamente en cm y kg.
    final double lengthCm = _read(_lengthController) * (_imperial ? _cmPerInch : 1);
    final double widthCm = _read(_widthController) * (_imperial ? _cmPerInch : 1);
    final double heightCm = _read(_heightController) * (_imperial ? _cmPerInch : 1);
    final double weightKg = _read(_weightController) * (_imperial ? _kgPerLb : 1);
    final double rateInput = _read(_rateController);
    final double ratePerKg = _imperial ? rateInput / _kgPerLb : rateInput;
    final int boxes = _read(_boxesController).round().clamp(1, 999).toInt();
    final double taxPercent = _read(_taxController);
    final double extra = _read(_extraController);

    final double volumetricKg = (lengthCm * widthCm * heightCm) / _divisor;
    final double chargeableKg = weightKg > volumetricKg ? weightKg : volumetricKg;
    final bool chargedByVolume = volumetricKg > weightKg;
    final double shippingCost = chargeableKg * ratePerKg * boxes;
    final double taxAmount = shippingCost * taxPercent / 100;
    final double total = shippingCost + taxAmount + (shippingCost > 0 ? extra : 0);
    final bool hasResult = chargeableKg > 0;

    double toUnit(double kg) => _imperial ? kg / _kgPerLb : kg;

    final bool showLocalEquivalent = total > 0 &&
        rateCurrency != finance.localCurrency &&
        currencyProvider.canConvert(rateCurrency, finance.localCurrency);
    final double localEquivalent = showLocalEquivalent
        ? currencyProvider.convert(total, rateCurrency, finance.localCurrency)
        : 0;

    final List<Map<String, dynamic>> presets = finance.shippingPresets;

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
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('cm / kg', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: true, label: Text('in / lb', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_imperial},
                    onSelectionChanged: (selection) {
                      final bool toImperial = selection.first;
                      // Los números ya escritos se convierten para que el
                      // envío siga siendo el mismo al cambiar de unidad.
                      void convert(TextEditingController c, double factor) {
                        final double v = _read(c);
                        if (v > 0) c.text = (v * factor).toStringAsFixed(2);
                      }

                      setState(() {
                        if (toImperial != _imperial) {
                          final double lengthFactor = toImperial ? 1 / _cmPerInch : _cmPerInch;
                          final double weightFactor = toImperial ? 1 / _kgPerLb : _kgPerLb;
                          convert(_lengthController, lengthFactor);
                          convert(_widthController, lengthFactor);
                          convert(_heightController, lengthFactor);
                          convert(_weightController, weightFactor);
                          // tarifa por kg <-> por lb va al revés que el peso
                          convert(_rateController, toImperial ? _kgPerLb : 1 / _kgPerLb);
                        }
                        _imperial = toImperial;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('${locale.t('envio_dimensiones')} ($lengthUnit)'),
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
                      Expanded(
                        child: _numberField(
                          _weightController,
                          '${locale.t('envio_peso_real_base')} ($weightUnit)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_boxesController, locale.t('envio_cajas'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(locale.t('envio_tarifa')),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          _rateController,
                          '${locale.t('envio_tarifa_por')} $weightUnit',
                        ),
                      ),
                      const SizedBox(width: 12),
                      CurrencyDropdown(
                        value: rateCurrency,
                        dense: true,
                        onChanged: (value) => setState(() => _rateCurrency = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _numberField(_taxController, locale.t('envio_impuestos'))),
                      const SizedBox(width: 12),
                      Expanded(child: _numberField(_extraController, locale.t('envio_cargo_extra'))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(locale.t('envio_tarifas_guardadas')),
                  const SizedBox(height: 8),
                  if (presets.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in presets)
                          InputChip(
                            label: Text(preset['name'] as String),
                            onPressed: () => _applyPreset(preset),
                            onDeleted: () => _deletePreset(finance, preset),
                          ),
                      ],
                    )
                  else
                    Text(locale.t('envio_sin_tarifas'), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _savePreset(finance, locale, rateCurrency),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(locale.t('envio_guardar_tarifa')),
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
                    _resultRow(theme, locale.t('envio_peso_real_base'),
                        '${toUnit(weightKg).toStringAsFixed(2)} $weightUnit'),
                    const SizedBox(height: 6),
                    _resultRow(theme, locale.t('envio_peso_volumetrico'),
                        '${toUnit(volumetricKg).toStringAsFixed(2)} $weightUnit'),
                    const Divider(height: 24),
                    _resultRow(
                      theme,
                      locale.t('envio_peso_a_cobrar'),
                      '${toUnit(chargeableKg).toStringAsFixed(2)} $weightUnit',
                      bold: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chargedByVolume
                          ? locale.t('envio_cobra_por_volumen')
                          : locale.t('envio_cobra_por_peso'),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (shippingCost > 0) ...[
                      const SizedBox(height: 14),
                      if (taxAmount > 0 || extra > 0) ...[
                        _resultRow(theme, locale.t('envio_costo_base'), formatCurrency(shippingCost, rateCurrency)),
                        if (taxAmount > 0) ...[
                          const SizedBox(height: 4),
                          _resultRow(theme, locale.t('envio_impuestos'), formatCurrency(taxAmount, rateCurrency)),
                        ],
                        if (extra > 0) ...[
                          const SizedBox(height: 4),
                          _resultRow(theme, locale.t('envio_cargo_extra'), formatCurrency(extra, rateCurrency)),
                        ],
                        const SizedBox(height: 10),
                      ],
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
                                formatCurrency(total, rateCurrency),
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
                                '$boxes × ${formatCurrency(total / boxes, rateCurrency)}',
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
                          cost: total,
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
        Flexible(
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : null)),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w600),
        ),
      ],
    );
  }
}
