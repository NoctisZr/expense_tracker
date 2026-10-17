import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../services/receipt_ocr_service.dart';
import '../utils/currency_list.dart';
import '../utils/formatters.dart';
import '../utils/receipt_parser.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';

/// Flujo completo "escanear factura": elegir cámara o galería, leer el
/// texto (OCR en el teléfono), interpretarlo y mostrar un formulario ya
/// rellenado para revisar y guardar con un toque.
Future<void> startReceiptScan(BuildContext context) async {
  final locale = context.read<LocaleProvider>();
  final messenger = ScaffoldMessenger.of(context);

  if (!ReceiptOcrService.isAvailable) {
    messenger.showSnackBar(SnackBar(content: Text(locale.t('ocr_no_disponible'))));
    return;
  }

  final ImageSource? source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(locale.t('desde_camara')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(locale.t('desde_galeria')),
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source, maxWidth: 2200, imageQuality: 90);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(locale.t('factura_error_camara'))));
    return;
  }
  if (picked == null || !context.mounted) return;

  // Indicador mientras se lee la imagen.
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 18),
            Expanded(child: Text(locale.t('leyendo_factura'))),
          ],
        ),
      ),
    ),
  );

  String text = '';
  try {
    text = await ReceiptOcrService().recognizeText(picked.path);
  } catch (_) {
    text = '';
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  final finance = context.read<FinanceProvider>();
  final ReceiptData data = parseReceiptText(
    text,
    defaultCurrency: finance.localCurrency,
    supportedCurrencies: kSupportedCurrencies.toSet(),
  );
  await showDialog(
    context: context,
    builder: (_) => _ReceiptReviewDialog(imagePath: picked!.path, data: data),
  );
}

class _ReceiptReviewDialog extends StatefulWidget {
  final String imagePath;
  final ReceiptData data;

  const _ReceiptReviewDialog({required this.imagePath, required this.data});

  @override
  State<_ReceiptReviewDialog> createState() => _ReceiptReviewDialogState();
}

class _ReceiptReviewDialogState extends State<_ReceiptReviewDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _currency;
  late String _category;
  late DateTime _date;
  bool _showRaw = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ReceiptData d = widget.data;
    final String local = context.read<FinanceProvider>().localCurrency;
    _nameController = TextEditingController(text: d.merchant ?? '');
    _amountController = TextEditingController(text: d.total == null ? '' : d.total!.toStringAsFixed(2));
    _noteController = TextEditingController();
    _currency = d.currency ?? local;
    _category = d.categoryGuess ?? ExpenseCategory.compras;
    _date = d.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
  }

  /// Copia la foto al almacenamiento de la app (la del selector es temporal).
  Future<String?> _persistImage() async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory('${docs.path}/receipts');
      if (!await dir.exists()) await dir.create(recursive: true);
      final String ext = widget.imagePath.contains('.') ? widget.imagePath.split('.').last : 'jpg';
      final File target =
          File('${dir.path}/receipt_${DateTime.now().microsecondsSinceEpoch}.$ext');
      await File(widget.imagePath).copy(target.path);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final locale = context.read<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final String name = _nameController.text.trim();
    final double? amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(locale.t('campos_gasto_invalidos'))));
      return;
    }

    setState(() => _saving = true);
    final String? savedPath = await _persistImage();

    double? localAmount;
    if (_currency != finance.localCurrency &&
        currencyProvider.canConvert(_currency, finance.localCurrency)) {
      localAmount = currencyProvider.convert(amount, _currency, finance.localCurrency);
    }

    finance.addExpense(
      name: name,
      amount: amount,
      currency: _currency,
      category: _category,
      date: _date,
      note: _noteController.text,
      localAmount: localAmount,
      receiptPath: savedPath,
    );
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(locale.t('factura_guardada'))));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final bool noTotal = widget.data.total == null;

    return AlertDialog(
      title: Text(locale.t('revisar_factura')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 130,
                width: double.infinity,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (noTotal)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  locale.t('factura_sin_total'),
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(locale.t('factura_revisa'), style: theme.textTheme.bodySmall),
              ),
            CategorySelectorRow(
              selected: _category,
              locale: locale,
              onChanged: (cat) => setState(() => _category = cat),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: locale.t('monto')),
                  ),
                ),
                const SizedBox(width: 10),
                CurrencyDropdown(
                  value: _currency,
                  dense: true,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nota_opcional')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(formatDateShort(_date)),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() => _showRaw = !_showRaw),
              child: Text(locale.t('ver_texto_leido')),
            ),
            if (_showRaw)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                ),
                child: Text(
                  widget.data.rawText.isEmpty ? '—' : widget.data.rawText,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}

/// Muestra a pantalla casi completa la foto adjunta a un gasto.
Future<void> showReceiptViewer(BuildContext context, String path) {
  final locale = context.read<LocaleProvider>();
  return showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(locale.t('recibo_no_disponible')),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}
