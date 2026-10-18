import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyRatesResult {
  /// Unidades de cada divisa por 1 USD.
  final Map<String, double> rates;

  /// Momento en que el PROVEEDOR publicó estos datos (no cuándo se
  /// descargaron).
  final DateTime updatedAt;

  /// Nombre de la fuente (para mostrarlo al usuario).
  final String source;

  CurrencyRatesResult({required this.rates, required this.updatedAt, this.source = ''});
}

class CurrencyApiException implements Exception {
  final String message;
  CurrencyApiException(this.message);

  @override
  String toString() => message;
}

/// Descarga tasas de cambio.
///
/// - Sin clave: consulta varias fuentes gratuitas A LA VEZ y usa la más
///   reciente (las fuentes gratuitas publican nuevos datos una vez al día).
/// - Con una clave gratuita de Open Exchange Rates: tasas actualizadas cada
///   hora.
class CurrencyApiService {
  static const String _erApiUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String _erApiV4Url = 'https://api.exchangerate-api.com/v4/latest/USD';
  static const String _openExchangeUrl = 'https://openexchangerates.org/api/latest.json';

  /// Archivos estáticos de currency-api (claves en minúscula bajo "usd").
  static const List<String> _staticUrls = [
    'https://latest.currency-api.pages.dev/v1/currencies/usd.json',
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json',
  ];

  static const Duration _timeout = Duration(seconds: 12);
  static const Map<String, String> _headers = {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
  };

  /// Diferencia máxima para considerar que dos fuentes tienen datos "igual
  /// de recientes" (entonces gana la de mayor prioridad).
  static const Duration _freshnessTolerance = Duration(hours: 6);

  Future<CurrencyRatesResult> fetchLatestRates({String? openExchangeAppId}) async {
    final List<String> errors = [];

    // 1) Con clave de Open Exchange Rates: datos de la última hora.
    final String? appId = openExchangeAppId?.trim();
    if (appId != null && appId.isNotEmpty) {
      try {
        return await _fetchOpenExchange(appId);
      } on CurrencyApiException catch (e) {
        errors.add(e.message);
      } catch (_) {
        errors.add('No se pudo conectar con Open Exchange Rates.');
      }
    }

    // 2) Fuentes gratuitas: todas a la vez; gana la más reciente.
    Future<CurrencyRatesResult?> guard(Future<CurrencyRatesResult> Function() fn) async {
      try {
        return await fn();
      } on CurrencyApiException catch (e) {
        errors.add(e.message);
        return null;
      } catch (_) {
        return null;
      }
    }

    final List<CurrencyRatesResult?> results = await Future.wait<CurrencyRatesResult?>([
      guard(_fetchErApi),
      guard(_fetchErApiV4),
      for (final url in _staticUrls) guard(() => _fetchStatic(url)),
    ]);

    final List<CurrencyRatesResult> ok = [];
    for (final r in results) {
      if (r != null) ok.add(r);
    }
    if (ok.isEmpty) {
      throw CurrencyApiException(
        errors.isNotEmpty ? errors.first : 'No se pudo conectar con el servidor de tasas.',
      );
    }
    return mergeBySourceFreshness(ok);
  }

  /// Elige como base la fuente más reciente (a igualdad de frescura, la de
  /// menor índice = mayor prioridad) y completa con divisas que ella no
  /// trae usando las demás fuentes. Pública para poder probarla.
  static CurrencyRatesResult mergeBySourceFreshness(List<CurrencyRatesResult> results) {
    assert(results.isNotEmpty);
    DateTime newest = results.first.updatedAt;
    for (final r in results) {
      if (r.updatedAt.isAfter(newest)) newest = r.updatedAt;
    }
    int baseIndex = 0;
    for (int i = 0; i < results.length; i++) {
      if (newest.difference(results[i].updatedAt) <= _freshnessTolerance) {
        baseIndex = i;
        break;
      }
    }
    final CurrencyRatesResult base = results[baseIndex];
    final Map<String, double> merged = Map<String, double>.of(base.rates);
    for (int i = 0; i < results.length; i++) {
      if (i == baseIndex) continue;
      results[i].rates.forEach((code, value) => merged.putIfAbsent(code, () => value));
    }
    return CurrencyRatesResult(rates: merged, updatedAt: base.updatedAt, source: base.source);
  }

  // -----------------------------------------------------------------------
  // Descargas
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> _getJson(Uri uri, {String? label}) async {
    late final http.Response response;
    try {
      response = await http.get(uri, headers: _headers).timeout(_timeout);
    } catch (_) {
      throw CurrencyApiException('No se pudo conectar con el servidor de tasas.');
    }
    if (response.statusCode == 429) {
      throw CurrencyApiException('${label ?? 'El servidor de tasas'} limitó las consultas (429). Intenta en unos minutos.');
    }
    if (response.statusCode != 200) {
      throw CurrencyApiException(
        '${label ?? 'El servidor de tasas'} respondió con un error (${response.statusCode}).',
      );
    }
    try {
      final dynamic decoded = json.decode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw CurrencyApiException('La respuesta de tasas no tiene un formato válido.');
  }

  Future<CurrencyRatesResult> _fetchErApi() async =>
      parseErApi(await _getJson(Uri.parse(_erApiUrl), label: 'open.er-api.com'));

  Future<CurrencyRatesResult> _fetchErApiV4() async =>
      parseErApiV4(await _getJson(Uri.parse(_erApiV4Url), label: 'exchangerate-api.com'));

  Future<CurrencyRatesResult> _fetchStatic(String url) async {
    // El parámetro "t" cambia cada minuto para saltarse cachés intermedias.
    final Uri uri = Uri.parse('$url?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');
    return parseStaticRates(await _getJson(uri, label: Uri.parse(url).host), Uri.parse(url).host);
  }

  Future<CurrencyRatesResult> _fetchOpenExchange(String appId) async {
    late final http.Response response;
    try {
      response = await http
          .get(Uri.parse('$_openExchangeUrl?app_id=${Uri.encodeQueryComponent(appId)}'), headers: _headers)
          .timeout(_timeout);
    } catch (_) {
      throw CurrencyApiException('No se pudo conectar con Open Exchange Rates.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CurrencyApiException('La clave de Open Exchange Rates no es válida.');
    }
    if (response.statusCode == 429) {
      throw CurrencyApiException('Se alcanzó el límite mensual de Open Exchange Rates.');
    }
    if (response.statusCode != 200) {
      throw CurrencyApiException('Open Exchange Rates respondió con un error (${response.statusCode}).');
    }
    try {
      return parseOpenExchange(Map<String, dynamic>.from(json.decode(response.body) as Map));
    } on CurrencyApiException {
      rethrow;
    } catch (_) {
      throw CurrencyApiException('La respuesta de Open Exchange Rates no es válida.');
    }
  }

  // -----------------------------------------------------------------------
  // Interpretación de respuestas (funciones puras, fáciles de probar)
  // -----------------------------------------------------------------------

  static Map<String, double> _toRates(dynamic raw, {bool upper = false}) {
    if (raw is! Map) throw CurrencyApiException('La API de tasas no devolvió datos válidos.');
    final Map<String, double> rates = {'USD': 1.0};
    raw.forEach((key, value) {
      if (value is num && value > 0) {
        rates[upper ? key.toString().toUpperCase() : key.toString()] = value.toDouble();
      }
    });
    if (rates.length < 20) {
      throw CurrencyApiException('La API de tasas devolvió muy pocas divisas.');
    }
    return rates;
  }

  static DateTime _fromUnixSeconds(dynamic value) =>
      DateTime.fromMillisecondsSinceEpoch((value as num).toInt() * 1000, isUtc: true).toLocal();

  /// open.er-api.com: {"result":"success","time_last_update_unix":...,"rates":{...}}
  static CurrencyRatesResult parseErApi(Map<String, dynamic> data) {
    if (data['result'] != 'success') {
      throw CurrencyApiException('La API de tasas no devolvió datos válidos.');
    }
    final dynamic ts = data['time_last_update_unix'];
    return CurrencyRatesResult(
      rates: _toRates(data['rates']),
      updatedAt: ts is num ? _fromUnixSeconds(ts) : DateTime.now(),
      source: 'open.er-api.com',
    );
  }

  /// api.exchangerate-api.com/v4: {"date":"2026-10-17","time_last_updated":...,"rates":{...}}
  static CurrencyRatesResult parseErApiV4(Map<String, dynamic> data) {
    final dynamic ts = data['time_last_updated'];
    DateTime updatedAt;
    if (ts is num) {
      updatedAt = _fromUnixSeconds(ts);
    } else {
      final DateTime? day = DateTime.tryParse(data['date']?.toString() ?? '');
      updatedAt = day == null ? DateTime.now() : DateTime.utc(day.year, day.month, day.day).toLocal();
    }
    return CurrencyRatesResult(
      rates: _toRates(data['rates']),
      updatedAt: updatedAt,
      source: 'exchangerate-api.com',
    );
  }

  /// currency-api (archivo estático): {"date":"2026-10-17","usd":{"eur":0.9,...}}
  static CurrencyRatesResult parseStaticRates(Map<String, dynamic> data, String sourceName) {
    final DateTime? day = DateTime.tryParse(data['date']?.toString() ?? '');
    return CurrencyRatesResult(
      rates: _toRates(data['usd'], upper: true),
      updatedAt: day == null ? DateTime.now() : DateTime.utc(day.year, day.month, day.day).toLocal(),
      source: sourceName,
    );
  }

  /// Open Exchange Rates: {"timestamp":1760659201,"base":"USD","rates":{...}}
  static CurrencyRatesResult parseOpenExchange(Map<String, dynamic> data) {
    final dynamic ts = data['timestamp'];
    if (ts is! num) throw CurrencyApiException('La respuesta de Open Exchange Rates no es válida.');
    return CurrencyRatesResult(
      rates: _toRates(data['rates']),
      updatedAt: _fromUnixSeconds(ts),
      source: 'openexchangerates.org',
    );
  }
}
