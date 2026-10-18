import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/currency_api_service.dart';

Map<String, dynamic> _rates({String? only, bool lower = false}) {
  final Map<String, dynamic> m = {};
  for (int i = 0; i < 25; i++) {
    final String code = 'C${i.toString().padLeft(2, '0')}';
    m[lower ? code.toLowerCase() : code] = 1.0 + i;
  }
  m[lower ? 'eur' : 'EUR'] = 0.9;
  if (only != null) m[lower ? only.toLowerCase() : only] = 123.4;
  return m;
}

CurrencyRatesResult _result(String source, DateTime at, {Map<String, double>? rates}) {
  return CurrencyRatesResult(
    rates: rates ?? {'USD': 1.0, 'EUR': 0.9},
    updatedAt: at,
    source: source,
  );
}

void main() {
  group('parsers', () {
    test('open.er-api.com', () {
      final r = CurrencyApiService.parseErApi({
        'result': 'success',
        'time_last_update_unix': 1760659201,
        'rates': _rates(),
      });
      expect(r.updatedAt.toUtc(), DateTime.fromMillisecondsSinceEpoch(1760659201000, isUtc: true));
      expect(r.rates['EUR'], 0.9);
      expect(r.rates['USD'], 1.0);
      expect(r.source, 'open.er-api.com');
    });

    test('respuesta de error lanza CurrencyApiException', () {
      expect(
        () => CurrencyApiService.parseErApi({'result': 'error', 'rates': _rates()}),
        throwsA(isA<CurrencyApiException>()),
      );
    });

    test('muy pocas divisas se considera inválido', () {
      expect(
        () => CurrencyApiService.parseErApi({
          'result': 'success',
          'rates': {'EUR': 0.9, 'BRL': 5.2},
        }),
        throwsA(isA<CurrencyApiException>()),
      );
    });

    test('exchangerate-api v4 con marca de tiempo', () {
      final r = CurrencyApiService.parseErApiV4({
        'date': '2026-10-17',
        'time_last_updated': 1760659201,
        'rates': _rates(),
      });
      expect(r.updatedAt.toUtc(), DateTime.fromMillisecondsSinceEpoch(1760659201000, isUtc: true));
    });

    test('currency-api estático: claves en minúscula pasan a mayúscula', () {
      final r = CurrencyApiService.parseStaticRates(
        {'date': '2026-10-17', 'usd': _rates(only: 'ves', lower: true)},
        'latest.currency-api.pages.dev',
      );
      expect(r.rates['VES'], 123.4);
      expect(r.rates['EUR'], 0.9);
      expect(r.updatedAt.toUtc(), DateTime.utc(2026, 10, 17));
      expect(r.source, 'latest.currency-api.pages.dev');
    });

    test('Open Exchange Rates (por hora)', () {
      final r = CurrencyApiService.parseOpenExchange({
        'timestamp': 1760662800,
        'base': 'USD',
        'rates': _rates(),
      });
      expect(r.updatedAt.toUtc(), DateTime.fromMillisecondsSinceEpoch(1760662800000, isUtc: true));
      expect(r.source, 'openexchangerates.org');
    });
  });

  group('mergeBySourceFreshness', () {
    final DateTime now = DateTime.utc(2026, 10, 17, 12);

    test('gana la fuente más reciente frente a una vieja', () {
      final merged = CurrencyApiService.mergeBySourceFreshness([
        _result('vieja', now.subtract(const Duration(hours: 30))),
        _result('nueva', now),
      ]);
      expect(merged.source, 'nueva');
      expect(merged.updatedAt, now);
    });

    test('a igualdad de frescura (±6 h) gana la de mayor prioridad', () {
      final merged = CurrencyApiService.mergeBySourceFreshness([
        _result('principal', now.subtract(const Duration(hours: 2))),
        _result('respaldo', now),
      ]);
      expect(merged.source, 'principal');
    });

    test('completa divisas que la fuente base no trae', () {
      final merged = CurrencyApiService.mergeBySourceFreshness([
        _result('nueva', now, rates: {'USD': 1.0, 'EUR': 0.9}),
        _result('vieja', now.subtract(const Duration(hours: 40)), rates: {'USD': 1.0, 'EUR': 0.8, 'VES': 40.0}),
      ]);
      expect(merged.source, 'nueva');
      expect(merged.rates['EUR'], 0.9); // la base manda
      expect(merged.rates['VES'], 40.0); // completada
    });
  });
}
