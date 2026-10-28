import 'csv_utils.dart';
import 'receipt_parser.dart';

/// Datos que se logran leer de un SMS o notificación de un banco.
class BankMessageData {
  final double? amount;
  final String? currency;
  final String? merchant;
  final DateTime? date;
  final bool isIncome;
  final String? categoryGuess;
  final String rawText;

  const BankMessageData({
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.date,
    required this.isIncome,
    required this.categoryGuess,
    required this.rawText,
  });
}

// Número con miles y decimales opcionales: 45.90 · 1,234.56 · 1.234,56 · 30,00
const String _amt = r'\d+(?:[.,]\d{3})*(?:[.,]\d{1,2})?';

final RegExp _symbolBefore = RegExp(r'(S/\.?|R\$|US\$|€|£|\$)\s*(' + _amt + r')');

const List<String> _balanceWords = [
  'saldo', 'disponible', 'balance', 'available', 'limite', 'límite', 'limit', 'linea', 'línea',
];

const List<String> _incomeWords = [
  'deposito', 'depósito', 'abono', 'recibiste', 'te transfirieron', 'te han transferido',
  'transferencia recibida', 'sueldo', 'haber', 'received', 'deposit', 'credited', 'salary',
  'recebeu', 'você recebeu', 'voce recebeu', 'crédito em conta', 'credito em conta',
];

const List<String> _expenseWords = [
  'compra', 'consumo', 'pago', 'pagaste', 'retiro', 'débito', 'debito', 'cargo', 'purchase',
  'spent', 'paid', 'withdrawal', 'debited', 'pagamento', 'gasto', 'payment',
];

final RegExp _noiseDates = RegExp(r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b|\b\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}\b');
final RegExp _noiseTimes = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:[ap]\.?m\.?)?', caseSensitive: false);
final RegExp _noiseCards = RegExp(
  r'(?:\*+|x{2,}|terminad[ao]\s+en|terminada\s+en|ending\s+(?:in\s+)?|finalizada\s+em|final)\s*\d{3,4}\b|tarjeta\s*(?:n[°º]?\s*)?\d+|\b\d{6,}\b',
  caseSensitive: false,
);

String _cleanForAmounts(String text) => text
    .replaceAll(_noiseDates, ' ')
    .replaceAll(_noiseTimes, ' ')
    .replaceAll(_noiseCards, ' ');

bool _hasBalanceBefore(String text, int start) {
  final int from = start - 28 < 0 ? 0 : start - 28;
  final String before = text.substring(from, start).toLowerCase();
  return _balanceWords.any(before.contains);
}

class _Found {
  final int start;
  final double amount;
  final String? token;
  const _Found(this.start, this.amount, this.token);
}

String? _currencyFromToken(String? token, String defaultCurrency, Set<String> supported) {
  if (token == null) return null;
  switch (token) {
    case 'S/':
    case 'S/.':
      return supported.contains('PEN') ? 'PEN' : null;
    case r'R$':
      return supported.contains('BRL') ? 'BRL' : null;
    case r'US$':
      return 'USD';
    case '€':
      return supported.contains('EUR') ? 'EUR' : null;
    case '£':
      return supported.contains('GBP') ? 'GBP' : null;
    case r'$':
      const dollars = {'USD', 'MXN', 'ARS', 'CLP', 'COP', 'CAD', 'AUD', 'UYU', 'DOP'};
      return dollars.contains(defaultCurrency) ? defaultCurrency : 'USD';
    default:
      return supported.contains(token) ? token : null;
  }
}

String _titleCase(String s) {
  final bool allUpper = s == s.toUpperCase() && s.length > 3;
  if (!allUpper) return s;
  return s
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

const List<String> _merchantBad = [
  'tu ', 'su ', 'your ', 'sua ', 'seu ', 'la ', 'el ', 'tarjeta', 'cuenta', 'account', 'card',
  'linea', 'línea', 'cta', 'conta', 'cartão', 'cartao', 'the ',
];

String? _findMerchantInMessage(String text) {
  final RegExp pattern = RegExp(
    r'\b(?:en|at|em|comercio|merchant|establecimiento|estabelecimento)\s*:?\s+(.+?)'
    r'(?=\s+(?:el|on|con|with|a\s+las|desde|from|do\s+dia|no\s+dia|em|por|for|usando|using)\b|[.,;]\s|[.,;]$|$)',
    caseSensitive: false,
  );
  for (final m in pattern.allMatches(text)) {
    String name = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    final String lower = '${name.toLowerCase()} ';
    if (name.length < 3) continue;
    if (_merchantBad.any(lower.startsWith)) continue;
    if (RegExp(r'^[\d\s.,]+$').hasMatch(name)) continue;
    if (name.length > 40) name = name.substring(0, 40).trim();
    return _titleCase(name);
  }
  return null;
}

/// Interpreta el texto de un SMS o notificación bancaria. Es una heurística:
/// el resultado siempre se muestra al usuario para que lo revise.
BankMessageData parseBankMessage(
  String text, {
  required String defaultCurrency,
  required Set<String> supportedCurrencies,
}) {
  final String flat = text.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final String clean = _cleanForAmounts(flat);

  final List<_Found> found = [];
  for (final m in _symbolBefore.allMatches(clean)) {
    final double? v = parseFlexibleAmount(m.group(2)!);
    if (v != null && v > 0) found.add(_Found(m.start, v, m.group(1)));
  }
  if (supportedCurrencies.isNotEmpty) {
    final String codes = supportedCurrencies.join('|');
    final RegExp codeBefore = RegExp(r'\b(' + codes + r')\s*(' + _amt + r')');
    final RegExp codeAfter = RegExp(r'(' + _amt + r')\s*(' + codes + r')\b');
    for (final m in codeBefore.allMatches(clean)) {
      final double? v = parseFlexibleAmount(m.group(2)!);
      if (v != null && v > 0) found.add(_Found(m.start, v, m.group(1)));
    }
    for (final m in codeAfter.allMatches(clean)) {
      final double? v = parseFlexibleAmount(m.group(1)!);
      if (v != null && v > 0) found.add(_Found(m.start, v, m.group(2)));
    }
  }
  found.sort((a, b) => a.start.compareTo(b.start));

  double? amount;
  String? currency;
  for (final f in found) {
    if (_hasBalanceBefore(clean, f.start)) continue;
    amount = f.amount;
    currency = _currencyFromToken(f.token, defaultCurrency, supportedCurrencies);
    break;
  }

  // Sin símbolo ni código: primer número con decimales (o tras "por/de/monto").
  if (amount == null) {
    final RegExp keyword = RegExp(
      r'\b(?:por|de|monto|importe|amount|of|valor|total|spent|paid|pagaste|pago)\s+(' + _amt + r')',
      caseSensitive: false,
    );
    for (final m in keyword.allMatches(clean)) {
      if (_hasBalanceBefore(clean, m.start)) continue;
      final double? v = parseFlexibleAmount(m.group(1)!);
      if (v != null && v > 0) {
        amount = v;
        break;
      }
    }
  }
  if (amount == null) {
    for (final m in RegExp(r'(?<![\d.,])\d+[.,]\d{2}(?![\d])').allMatches(clean)) {
      if (_hasBalanceBefore(clean, m.start)) continue;
      final double? v = parseFlexibleAmount(m.group(0)!);
      if (v != null && v > 0) {
        amount = v;
        break;
      }
    }
  }

  final String lower = flat.toLowerCase();
  final bool incomeHit = _incomeWords.any(lower.contains);
  final bool expenseHit = _expenseWords.any(lower.contains);
  final String? merchant = _findMerchantInMessage(flat);

  return BankMessageData(
    amount: amount,
    currency: currency,
    merchant: merchant,
    date: findDateInText(flat),
    isIncome: incomeHit && !expenseHit,
    categoryGuess: guessCategoryFromText(flat, merchant),
    rawText: text.trim(),
  );
}
