import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/currency_api_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _cachedRatesKey = 'cachedRates';
  static const String _cachedUpdatedAtKey = 'cachedRatesUpdatedAt';
  static const String _manualRatesKey = 'manualRates';

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
  DateTime? _lastUpdated;
  DateTime? _lastAttempt;

  CurrencyProvider(this.settingsBox, {CurrencyApiService? apiService})
      : _apiService = apiService ?? CurrencyApiService() {
    _loadCachedRates();
    _loadManualRates();
    _rebuildRates();
    fetchRates();
  }

  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
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
  }

  Future<void> _cacheRates() async {
    await settingsBox.put(_cachedRatesKey, _apiRates);
    if (_lastUpdated != null) {
      await settingsBox.put(
        _cachedUpdatedAtKey,
        _lastUpdated!.toIso8601String(),
      );
    }
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

  Future<void> fetchRates() async {
    _lastAttempt = DateTime.now();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final CurrencyRatesResult result = await _apiService.fetchLatestRates();
      _apiRates = result.rates;
      _rebuildRates();
      _lastUpdated = result.updatedAt;
      await _cacheRates();
    } on CurrencyApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar las tasas de cambio.';
    }

    _isLoading = false;
    notifyListeners();
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
