import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/rate_alert.dart';
import '../services/currency_api_service.dart';
import '../utils/currency_list.dart';
import '../utils/id_generator.dart';

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
  static const String _historyKey = 'rateHistory';
  static const String _alertsKey = 'rateAlerts';
  static const int _historyDays = 180;

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

  /// Historial local: día (aaaa-mm-dd, UTC) -> tasas de las divisas
  /// soportadas. Se va llenando con cada actualización con datos nuevos.
  Map<String, Map<String, double>> _history = {};

  /// Se llama cuando, tras actualizar las tasas, se cumplen alertas.
  void Function(List<RateAlert> alerts)? onAlertsFired;

  CurrencyProvider(this.settingsBox, {CurrencyApiService? apiService})
      : _apiService = apiService ?? CurrencyApiService() {
    _openExchangeAppId = settingsBox.get(_appIdKey) as String?;
    _loadCachedRates();
    _loadHistory();
    _loadManualRates();
    _rebuildRates();
    // La primera descarga ya no se lanza aquí: HomeScreen llama a
    // refreshIfStale() un instante después de dibujar la pantalla.
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
        _recordHistory(result);
      }
      _lastFetchedAt = DateTime.now();
      await _cacheRates();
      final List<RateAlert> fired = evaluateAlerts();
      if (fired.isNotEmpty) onAlertsFired?.call(fired);
    } on CurrencyApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'No se pudo actualizar las tasas de cambio.';
    }

    _isLoading = false;
    notifyListeners();
    return outcome;
  }

  // ---------------------------------------------------------------------
  // Historial de tasas (para el gráfico de evolución)
  // ---------------------------------------------------------------------

  static String _dayKey(DateTime d) {
    final DateTime u = d.toUtc();
    return '${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
  }

  void _loadHistory() {
    final dynamic raw = settingsBox.get(_historyKey);
    final Map<String, Map<String, double>> loaded = {};
    if (raw is Map) {
      raw.forEach((day, rates) {
        if (rates is Map) {
          final Map<String, double> byCode = {};
          rates.forEach((code, value) {
            if (value is num && value > 0) byCode[code.toString()] = value.toDouble();
          });
          if (byCode.isNotEmpty) loaded[day.toString()] = byCode;
        }
      });
    }
    _history = loaded;
  }

  void _recordHistory(CurrencyRatesResult result) {
    final Map<String, double> snapshot = {
      for (final code in kSupportedCurrencies)
        if (result.rates.containsKey(code)) code: result.rates[code]!,
    };
    if (snapshot.length < 2) return;
    _history[_dayKey(result.updatedAt)] = snapshot;
    if (_history.length > _historyDays) {
      final List<String> keys = _history.keys.toList()..sort();
      for (final k in keys.take(_history.length - _historyDays)) {
        _history.remove(k);
      }
    }
    settingsBox.put(_historyKey, _history);
  }

  /// Serie (fecha, valor de 1 [from] en [to]) de los últimos [days] días, de
  /// la más antigua a la más reciente. Solo incluye los días guardados.
  List<MapEntry<DateTime, double>> historyFor(String from, String to, int days) {
    final DateTime limit = DateTime.now().toUtc().subtract(Duration(days: days));
    final List<MapEntry<DateTime, double>> result = [];
    final List<String> keys = _history.keys.toList()..sort();
    for (final key in keys) {
      final DateTime? day = DateTime.tryParse(key);
      if (day == null || day.isBefore(DateTime.utc(limit.year, limit.month, limit.day))) continue;
      final Map<String, double> rates = _history[key]!;
      final double? a = rates[from];
      final double? b = rates[to];
      if (a == null || b == null || a <= 0) continue;
      result.add(MapEntry(day, b / a));
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Alertas de tasa
  // ---------------------------------------------------------------------

  List<RateAlert> get rateAlerts {
    final dynamic raw = settingsBox.get(_alertsKey);
    final List<RateAlert> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(RateAlert.fromMap(item));
          } catch (_) {}
        }
      }
    }
    return result;
  }

  Future<void> _saveAlerts(List<RateAlert> list) async {
    await settingsBox.put(_alertsKey, list.map((a) => a.toMap()).toList());
  }

  Future<void> addRateAlert({
    required String from,
    required String to,
    required bool above,
    required double target,
  }) async {
    final List<RateAlert> list = rateAlerts
      ..add(RateAlert(id: generateId(), from: from, to: to, above: above, target: target));
    await _saveAlerts(list);
    notifyListeners();
  }

  Future<void> deleteRateAlert(String id) async {
    await _saveAlerts(rateAlerts.where((a) => a.id != id).toList());
    notifyListeners();
  }

  /// Revisa las alertas con las tasas actuales. Devuelve las que se cumplen
  /// ahora y no habían avisado en las últimas 12 horas (y las marca).
  List<RateAlert> evaluateAlerts() {
    final List<RateAlert> alerts = rateAlerts;
    if (alerts.isEmpty || !hasRates) return const [];
    final DateTime now = DateTime.now();
    final List<RateAlert> fired = [];
    final List<RateAlert> updated = [];
    for (final alert in alerts) {
      if (!canConvert(alert.from, alert.to)) {
        updated.add(alert);
        continue;
      }
      final double rate = convert(1, alert.from, alert.to);
      final bool recently = alert.lastTriggered != null &&
          now.difference(alert.lastTriggered!) < const Duration(hours: 12);
      if (alert.isReachedBy(rate) && !recently) {
        fired.add(alert);
        updated.add(alert.copyWith(lastTriggered: now));
      } else {
        updated.add(alert);
      }
    }
    if (fired.isNotEmpty) _saveAlerts(updated);
    return fired;
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
