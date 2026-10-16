import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyRatesResult {
  final Map<String, double> rates;
  final DateTime updatedAt;

  CurrencyRatesResult({required this.rates, required this.updatedAt});
}

class CurrencyApiException implements Exception {
  final String message;
  CurrencyApiException(this.message);

  @override
  String toString() => message;
}

class CurrencyApiService {
  static const String _baseUrl = 'https://open.er-api.com/v6/latest/USD';

  /// Fuentes de respaldo (formato distinto: claves en minúscula bajo "usd").
  /// Solo se consultan si la API principal falla.
  static const List<String> _fallbackUrls = [
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
    'https://latest.currency-api.pages.dev/v1/currencies/usd.json',
  ];
  static const Duration _timeout = Duration(seconds: 12);

  Future<CurrencyRatesResult> fetchLatestRates() async {
    try {
      return await _fetchPrimary();
    } on CurrencyApiException {
      final CurrencyRatesResult? fallback = await _fetchFallback();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<CurrencyRatesResult?> _fetchFallback() async {
    for (final String url in _fallbackUrls) {
      try {
        final http.Response response = await http.get(Uri.parse(url)).timeout(_timeout);
        if (response.statusCode != 200) continue;
        final Map<String, dynamic> decoded =
            json.decode(response.body) as Map<String, dynamic>;
        final dynamic usd = decoded['usd'];
        if (usd is! Map) continue;
        final Map<String, double> rates = {'USD': 1.0};
        usd.forEach((key, value) {
          if (value is num && value > 0) rates[key.toString().toUpperCase()] = value.toDouble();
        });
        // Se exige un mínimo razonable de divisas para dar la respuesta por válida.
        if (rates.length < 20) continue;
        final DateTime updatedAt =
            DateTime.tryParse(decoded['date']?.toString() ?? '') ?? DateTime.now();
        return CurrencyRatesResult(rates: rates, updatedAt: updatedAt);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<CurrencyRatesResult> _fetchPrimary() async {
    final Uri uri = Uri.parse(_baseUrl);

    late final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (_) {
      throw CurrencyApiException('No se pudo conectar con el servidor de tasas.');
    }

    if (response.statusCode != 200) {
      throw CurrencyApiException(
        'El servidor de tasas respondió con un error (${response.statusCode}).',
      );
    }

    late final Map<String, dynamic> decoded;
    try {
      decoded = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw CurrencyApiException('La respuesta de tasas no tiene un formato válido.');
    }

    if (decoded['result'] != 'success' || decoded['rates'] == null) {
      throw CurrencyApiException('La API de tasas no devolvió datos válidos.');
    }

    final Map<String, dynamic> rawRates = decoded['rates'] as Map<String, dynamic>;
    final Map<String, double> rates = rawRates.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    DateTime updatedAt;
    final dynamic unixTimestamp = decoded['time_last_update_unix'];
    if (unixTimestamp is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(
        unixTimestamp * 1000,
        isUtc: true,
      ).toLocal();
    } else {
      updatedAt = DateTime.now();
    }

    return CurrencyRatesResult(rates: rates, updatedAt: updatedAt);
  }
}
