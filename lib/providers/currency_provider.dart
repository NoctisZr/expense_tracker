import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/currency_api_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _cachedRatesKey = 'cachedRates';
  static const String _cachedUpdatedAtKey = 'cachedRatesUpdatedAt';

  final Box settingsBox;
  final CurrencyApiService _apiService;

  Map<String, double> _rates = {'USD': 1.0};
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdated;
  DateTime? _lastAttempt;

  CurrencyProvider(this.settingsBox, {CurrencyApiService? apiService})
      : _apiService = apiService ?? CurrencyApiService() {
    _loadCachedRates();
    fetchRates();
  }

  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasRates => _rates.length > 1;

  void _loadCachedRates() {
    final dynamic cached = settingsBox.get(_cachedRatesKey);
    if (cached is Map) {
      _rates = cached.map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      );
    }
    final dynamic cachedDate = settingsBox.get(_cachedUpdatedAtKey);
    if (cachedDate is String) {
      _lastUpdated = DateTime.tryParse(cachedDate);
    }
  }

  Future<void> _cacheRates() async {
    await settingsBox.put(_cachedRatesKey, _rates);
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
      _rates = result.rates;
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
