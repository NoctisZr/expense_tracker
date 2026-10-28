import 'csv_utils.dart';

/// Datos que se logran leer del texto de una factura o ticket.
class ReceiptData {
  final String? merchant;
  final double? total;
  final DateTime? date;
  final String? currency;
  final String? categoryGuess;
  final String rawText;

  const ReceiptData({
    required this.merchant,
    required this.total,
    required this.date,
    required this.currency,
    required this.categoryGuess,
    required this.rawText,
  });
}

const Map<String, int> _monthNames = {
  // español
  'ene': 1, 'enero': 1, 'feb': 2, 'febrero': 2, 'mar': 3, 'marzo': 3,
  'abr': 4, 'abril': 4, 'may': 5, 'mayo': 5, 'jun': 6, 'junio': 6,
  'jul': 7, 'julio': 7, 'ago': 8, 'agosto': 8, 'sep': 9, 'sept': 9, 'setiembre': 9, 'septiembre': 9,
  'oct': 10, 'octubre': 10, 'nov': 11, 'noviembre': 11, 'dic': 12, 'diciembre': 12,
  // inglés
  'jan': 1, 'january': 1, 'february': 2, 'march': 3, 'apr': 4, 'april': 4,
  'june': 6, 'july': 7, 'aug': 8, 'august': 8, 'september': 9,
  'october': 10, 'december': 12, 'dec': 12, 'november': 11,
  // portugués
  'fev': 2, 'fevereiro': 2, 'março': 3, 'marco': 3, 'maio': 5, 'junho': 6, 'julho': 7,
  'set': 9, 'setembro': 9, 'out': 10, 'outubro': 10, 'novembro': 11, 'dez': 12, 'dezembro': 12,
};

final RegExp _amountPattern = RegExp(
  r'(?<![\d.,])\d{1,3}(?:[.,\s]\d{3})+[.,]\d{2}(?![\d])|(?<![\d.,])\d+[.,]\d{2}(?![\d])',
);

const List<String> _totalKeywords = [
  'total a pagar', 'total pagar', 'importe total', 'monto total', 'valor total',
  'total general', 'total factura', 'grand total', 'amount due', 'total due',
  'neto a pagar', 'a pagar', 'total',
];

const List<String> _excludedKeywords = [
  'subtotal', 'sub total', 'sub-total', 'igv', 'iva', 'impuesto', 'tax', 'vuelto', 'cambio',
  'change', 'descuento', 'discount', 'propina', 'tip', 'efectivo', 'cash', 'tarjeta', 'card',
  'recibido', 'received',
];

const List<String> _merchantSkip = [
  'factura', 'boleta', 'ticket', 'recibo', 'receipt', 'invoice', 'ruc', 'nit', 'rfc', 'cnpj',
  'fecha', 'date', 'total', 'tel', 'telf', 'www', 'http', 'direccion', 'dirección', 'address',
  'cliente', 'customer', 'caja', 'cajero', 'serie', 'nro', 'numero', 'número', 'hora',
];

/// Palabras (completas) que delatan una línea que NO es el nombre del comercio.
final RegExp _merchantSkipPattern = RegExp(
  r'\b(?:' + _merchantSkip.map(RegExp.escape).join('|') + r')\b',
);

/// Convierte "1.234,56" / "1,234.56" / "12,50" en número.
double? _toAmount(String raw) => parseFlexibleAmount(raw.replaceAll(' ', ''));

List<double> _amountsIn(String line) {
  final List<double> result = [];
  for (final m in _amountPattern.allMatches(line)) {
    final double? v = _toAmount(m.group(0)!);
    if (v != null && v > 0) result.add(v);
  }
  return result;
}

DateTime? _findDate(String text) {
  final DateTime now = DateTime.now();
  bool plausible(DateTime d) => d.year >= 2000 && !d.isAfter(now.add(const Duration(days: 2)));

  // 16/10/2026, 16-10-2026, 16.10.2026, 2026-10-16, 16/10/26
  for (final m in RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b').allMatches(text)) {
    final int a = int.parse(m.group(1)!);
    final int b = int.parse(m.group(2)!);
    int y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    // Se asume día/mes/año (lo habitual en LatAm y Europa); si no cuadra, mes/día/año.
    if (b >= 1 && b <= 12 && a >= 1 && a <= 31) {
      final DateTime d = DateTime(y, b, a, 12);
      if (plausible(d)) return d;
    }
    if (a >= 1 && a <= 12 && b >= 1 && b <= 31) {
      final DateTime d = DateTime(y, a, b, 12);
      if (plausible(d)) return d;
    }
  }
  for (final m in RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b').allMatches(text)) {
    final int y = int.parse(m.group(1)!);
    final int mo = int.parse(m.group(2)!);
    final int d = int.parse(m.group(3)!);
    if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
      final DateTime date = DateTime(y, mo, d, 12);
      if (plausible(date)) return date;
    }
  }
  // 16 oct 2026 / 16 de octubre de 2026 / Oct 16, 2026
  for (final m in RegExp(r'\b(\d{1,2})\s*(?:de\s+)?([A-Za-zÀ-ÿ]{3,10})\.?\s*(?:de\s+|,\s*)?(\d{4})\b').allMatches(text)) {
    final int? month = _monthNames[m.group(2)!.toLowerCase()];
    if (month == null) continue;
    final DateTime d = DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!), 12);
    if (plausible(d)) return d;
  }
  for (final m in RegExp(r'\b([A-Za-zÀ-ÿ]{3,10})\.?\s+(\d{1,2}),?\s+(\d{4})\b').allMatches(text)) {
    final int? month = _monthNames[m.group(1)!.toLowerCase()];
    if (month == null) continue;
    final DateTime d = DateTime(int.parse(m.group(3)!), month, int.parse(m.group(2)!), 12);
    if (plausible(d)) return d;
  }
  return null;
}

String? _findCurrency(String text, String defaultCurrency, Set<String> supported) {
  final String upper = text.toUpperCase();
  if (RegExp(r'\bS/\.?\s*\d|\bS/\.?\s').hasMatch(text)) return supported.contains('PEN') ? 'PEN' : null;
  if (upper.contains('R\$')) return supported.contains('BRL') ? 'BRL' : null;
  if (RegExp(r'\bUS\$|\bUSD\b').hasMatch(upper)) return 'USD';
  for (final code in supported) {
    if (RegExp(r'\b' + code + r'\b').hasMatch(upper)) return code;
  }
  if (text.contains('€')) return supported.contains('EUR') ? 'EUR' : null;
  if (text.contains('£')) return supported.contains('GBP') ? 'GBP' : null;
  if (text.contains(r'$')) {
    // "$" es ambiguo: se usa la moneda local si también es una moneda "$".
    const dollarCurrencies = {'USD', 'MXN', 'ARS', 'CLP', 'COP', 'CAD', 'AUD', 'UYU', 'DOP'};
    return dollarCurrencies.contains(defaultCurrency) ? defaultCurrency : 'USD';
  }
  return null;
}

String? _findMerchant(List<String> lines) {
  for (final line in lines.take(6)) {
    final String lower = line.toLowerCase();
    final int letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(line).length;
    final int digits = RegExp(r'\d').allMatches(line).length;
    if (letters < 3 || digits > letters) continue;
    if (_merchantSkipPattern.hasMatch(lower)) continue;
    String name = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.length > 40) name = name.substring(0, 40).trim();
    return name;
  }
  return null;
}

const Map<String, List<String>> _categoryKeywords = {
  'comida': [
    'restaurant', 'restaurante', 'cafe', 'café', 'coffee', 'pizza', 'burger', 'hamburg', 'taco',
    'sushi', 'pollo', 'panader', 'bakery', 'bebida', 'menu', 'menú', 'delivery', 'supermerc',
    'supermarket', 'mercado', 'market', 'bodega', 'grill', 'cevich', 'pollería', 'polleria',
    'helad', 'bar ', 'pub', 'lanchonete', 'padaria', 'comida', 'food',
  ],
  'servicios': [
    'electric', 'luz ', 'agua', 'water', 'internet', 'claro', 'movistar', 'entel', 'vodafone',
    'telefon', 'gas ', 'seguro', 'insurance', 'suscrip', 'subscription', 'netflix', 'spotify',
    'servicio', 'service', 'cable', 'fibra', 'alquiler', 'rent',
  ],
};

String? _guessCategory(String text, String? merchant) {
  final String hay = '${merchant ?? ''}\n$text'.toLowerCase();
  for (final entry in _categoryKeywords.entries) {
    if (entry.value.any((k) => hay.contains(k))) return entry.key;
  }
  return null;
}

/// Interpreta el texto reconocido (OCR) de una factura/ticket. Es una
/// heurística: el resultado siempre se muestra al usuario para que lo
/// revise antes de guardar.
ReceiptData parseReceiptText(
  String text, {
  required String defaultCurrency,
  required Set<String> supportedCurrencies,
}) {
  final List<String> lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // --- Total: líneas con palabra clave (la línea o la siguiente) ---
  double? total;
  final List<double> keywordAmounts = [];
  for (int i = 0; i < lines.length; i++) {
    final String lower = lines[i].toLowerCase();
    if (_excludedKeywords.any((k) => lower.contains(k))) continue;
    if (!_totalKeywords.any((k) => lower.contains(k))) continue;
    List<double> found = _amountsIn(lines[i]);
    if (found.isEmpty && i + 1 < lines.length) {
      final String next = lines[i + 1].toLowerCase();
      if (!_excludedKeywords.any((k) => next.contains(k))) found = _amountsIn(lines[i + 1]);
    }
    keywordAmounts.addAll(found);
  }
  if (keywordAmounts.isNotEmpty) {
    total = keywordAmounts.reduce((a, b) => a > b ? a : b);
  } else {
    final List<double> all = [for (final l in lines) ..._amountsIn(l)];
    if (all.isNotEmpty) total = all.reduce((a, b) => a > b ? a : b);
  }

  final String? merchant = _findMerchant(lines);

  return ReceiptData(
    merchant: merchant,
    total: total,
    date: _findDate(text),
    currency: _findCurrency(text, defaultCurrency, supportedCurrencies),
    categoryGuess: _guessCategory(text, merchant),
    rawText: text,
  );
}

// --- Utilidades reutilizables por otros intérpretes de texto (SMS bancarios...) ---

DateTime? findDateInText(String text) => _findDate(text);

String? findCurrencyInText(String text, String defaultCurrency, Set<String> supported) =>
    _findCurrency(text, defaultCurrency, supported);

String? guessCategoryFromText(String text, String? merchant) => _guessCategory(text, merchant);
