import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/currency_api_service.dart';

/// Resultado de pedir las tasas.
enum RatesRefreshOutcome {
  /// Llegaron datos más recientes que los que había.
  updated,

  /// Se descargó bien, pero el proveedor aún no publicó datos nuevos.
  unchanged,

  /// No se pudo descargar.
  failed,

  /// No se consultó (ya se había actualizado hace un momento).
  skipped,
}

class CurrencyProvider extends ChangeNotifier {
  static const String _cachedRatesKey = 'cachedRates';
  static const String _cachedUpdatedAtKey = 'cachedRatesUpdatedAt';
  static const String _manualRatesKey = 'manualRates';
  static const String _fetchedAtKey = 'cachedRatesFetchedAt';
  static const String _sourceKey = 'cachedRatesSource';
  static const String _appIdKey = 'openExchangeAppId';

  final Box settingsBox;
  final CurrencyApiService _apiService;

  /// Tasas tal como las devolvió la API (unidades de cada divisa por 1 USD).
  Map<String, double> _apiRates = {'USD': 1.0};

  /// Tasas manuales del usuario (por ejemplo dólar paralelo). Pisan a las
  /// de la API solo para esa divisa.
  Map<String, double> _manualRates = {};

  /// Tasas efectivas = API + manuales. Es lo que usa `convert`.
  Map<String, double> _rates = {'USD': 1.0};
  bool _isLoading = false;
  String? _errorMessage;

  /// Cuándo el PROVEEDOR publicó los datos (cambia como mucho una vez al
  /// día con las fuentes gratuitas).
  DateTime? _lastUpdated;

  /// Cuándo se descargaron por última vez con éxito en este teléfono.
  DateTime? _lastFetchedAt;
  String? _source;
  String? _openExchangeAppId;
  DateTime? _lastAttempt;

  CurrencyProvider(this.settingsBox, {CurrencyApiService? apiService})
      : _apiService = apiService ?? CurrencyApiService() {
    _openExchangeAppId = settingsBox.get(_appIdKey) as String?;
    _loadCachedRates();
    _loadManualRates();
    _rebuildRates();
    fetchRates();
  }

  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  DateTime? get lastFetchedAt => _lastFetchedAt;
  String? get source => _source;
  String? get openExchangeAppId => _openExchangeAppId;

  /// `true` si hay una clave de Open Exchange Rates (tasas cada hora).
  bool get hasHourlyKey => (_openExchangeAppId ?? '').isNotEmpty;

  /// Guarda (o quita, si es vacía) la clave de Open Exchange Rates.
  Future<void> setOpenExchangeAppId(String? id) async {
    final String clean = (id ?? '').trim();
    _openExchangeAppId = clean.isEmpty ? null : clean;
    if (_openExchangeAppId == null) {
      await settingsBox.delete(_appIdKey);
    } else {
      await settingsBox.put(_appIdKey, _openExchangeAppId);
    }
    notifyListeners();
  }
  bool get hasRates => _rates.length > 1;

  /// Tasas manuales activas (código -> unidades por 1 USD).
  Map<String, double> get manualRates => Map.unmodifiable(_manualRates);

  /// Tasa que dio la API para [code] (sin tener en cuenta la manual).
  double? apiRateFor(String code) => _apiRates[code];

  bool isManual(String code) => _manualRates.containsKey(code);

  /// `true` si las tasas de la API tienen más de 36 horas.
  bool get isStale {
    final DateTime? updated = _lastUpdated;
    return updated == null || DateTime.now().difference(updated) > const Duration(hours: 36);
  }

  void _rebuildRates() {
    _rates = {..._apiRates, ..._manualRates};
  }

  void _loadManualRates() {
    final dynamic raw = settingsBox.get(_manualRatesKey);
    if (raw is Map) {
      final Map<String, double> loaded = {};
      raw.forEach((key, value) {
        if (value is num && value > 0) loaded[key.toString()] = value.toDouble();
      });
      _manualRates = loaded;
    }
  }

  /// Fija una tasa manual: 1 USD = [unitsPerUsd] unidades de [code].
  Future<void> setManualRate(String code, double unitsPerUsd) async {
    if (code == 'USD' || unitsPerUsd <= 0) return;
    _manualRates = {..._manualRates, code: unitsPerUsd};
    _rebuildRates();
    await settingsBox.put(_manualRatesKey, _manualRates);
    notifyListeners();
  }

  Future<void> clearManualRate(String code) async {
    if (!_manualRates.containsKey(code)) return;
    _manualRates = Map.of(_manualRates)..remove(code);
    _rebuildRates();
    await settingsBox.put(_manualRatesKey, _manualRates);
    notifyListeners();
  }

  void _loadCachedRates() {
    final dynamic cached = settingsBox.get(_cachedRatesKey);
    if (cached is Map) {
      _apiRates = cached.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
    }
    final dynamic cachedDate = settingsBox.get(_cachedUpdatedAtKey);
    if (cachedDate is String) {
      _lastUpdated = DateTime.tryParse(cachedDate);
    }
    final dynamic fetchedAt = settingsBox.get(_fetchedAtKey);
    if (fetchedAt is String) _lastFetchedAt = DateTime.tryParse(fetchedAt);
    final dynamic source = settingsBox.get(_sourceKey);
    if (source is String) _source = source;
  }

  Future<void> _cacheRates() async {
    await settingsBox.put(_cachedRatesKey, _apiRates);
    if (_lastUpdated != null) {
      await settingsBox.put(
        _cachedUpdatedAtKey,
        _lastUpdated!.toIso8601String(),
      );
    }
    if (_lastFetchedAt != null) {
      await settingsBox.put(_fetchedAtKey, _lastFetchedAt!.toIso8601String());
    }
    if (_source != null) await settingsBox.put(_sourceKey, _source);
  }

  /// Vuelve a pedir las tasas solo si pasó más de una hora desde el último
  /// intento (la API gratuita actualiza una vez al día y limita las
  /// consultas frecuentes). Se llama al volver a abrir la app.
  Future<void> refreshIfStale() async {
    if (_isLoading) return;
    final DateTime? last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) {
      return;
    }
    await fetchRates();
  }

  /// `true` si hay tasa para ambas divisas (evita convertir 1:1 sin querer).
  bool canConvert(String from, String to) {
    if (from == to) return true;
    return _rates.containsKey(from) && _rates.containsKey(to);
  }

  /// Descarga las tasas. Con [manual] = true (botón de actualizar) no
  /// consulta de nuevo si ya se actualizó hace un momento, salvo que se
  /// pase [force] (por ejemplo, al guardar una clave nueva).
  Future<RatesRefreshOutcome> fetchRates({bool manual = false, bool force = false}) async {
    if (_isLoading) return RatesRefreshOutcome.skipped;
    final DateTime now = DateTime.now();
    if (manual && !force && _lastFetchedAt != null) {
      final Duration cooldown =
          hasHourlyKey ? const Duration(minutes: 10) : const Duration(seconds: 60);
      if (now.difference(_lastFetchedAt!) < cooldown) return RatesRefreshOutcome.skipped;
    }

    _lastAttempt = now;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    RatesRefreshOutcome outcome = RatesRefreshOutcome.failed;
    try {
      final CurrencyRatesResult result =
          await _apiService.fetchLatestRates(openExchangeAppId: _openExchangeAppId);
      final DateTime? previous = _lastUpdated;
      final bool olderThanCache =
          previous != null && _apiRates.length > 1 && result.updatedAt.isBefore(previous);

      if (olderThanCache) {
        // Nunca se reemplazan datos más nuevos por otros más viejos.
        outcome = RatesRefreshOutcome.unchanged;
      } else {
        final bool newer = previous == null || result.updatedAt.isAfter(previous);
        _apiRates = result.rates;
        _rebuildRates();
        _lastUpdated = result.updatedAt;
        _source = result.source.isEmpty ? _source : result.source;
        outcome = newer ? RatesRefreshOutcome.updated : RatesRefreshOutcome.unchanged;
      }
      _lastFetchedAt = DateTime.now();
      await _cacheRates();
    } on CurrencyApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar las tasas de cambio.';
    }

    _isLoading = false;
    notifyListeners();
    return outcome;
  }

  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    final double fromRate = _rates[from] ?? 1.0;
    final double toRate = _rates[to] ?? 1.0;
    final double amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }

  double rateBetween(String from, String to) => convert(1, from, to);
}
