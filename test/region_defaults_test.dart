import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/region_service.dart';
import 'package:expense_tracker/utils/currency_list.dart';
import 'package:expense_tracker/utils/region_defaults.dart';

void main() {
  group('idioma por región', () {
    test('el país manda sobre la moneda', () {
      expect(languageForRegion(country: 'EC', currency: 'USD'), 'es'); // Ecuador usa USD
      expect(languageForRegion(country: 'PT', currency: 'EUR'), 'pt');
      expect(languageForRegion(country: 'ES', currency: 'EUR'), 'es');
      expect(languageForRegion(country: 'DE', currency: 'EUR'), 'en');
      expect(languageForRegion(country: 'US', currency: 'USD'), 'en');
    });
    test('sin país, la moneda decide (si tiene un solo idioma)', () {
      expect(languageForRegion(currency: 'PEN'), 'es');
      expect(languageForRegion(currency: 'BRL'), 'pt');
      expect(languageForRegion(currency: 'GBP'), 'en');
    });
    test('USD y EUR no sugieren idioma por sí solos', () {
      expect(languageForRegion(currency: 'USD'), isNull);
      expect(languageForRegion(currency: 'EUR'), isNull);
    });
    test('país en minúsculas y país desconocido', () {
      expect(languageForRegion(country: 'pe'), 'es');
      expect(languageForRegion(country: 'ZZ'), isNull);
    });
    test('toda moneda soportada con idioma único apunta a un idioma de la app', () {
      for (final c in kSupportedCurrencies) {
        final l = languageForRegion(currency: c);
        if (l != null) expect(kLanguageNames.containsKey(l), isTrue, reason: c);
      }
    });
    test('todo país con moneda conocida tiene idioma o cae a la moneda', () {
      for (final entry in kCountryToCurrency.entries) {
        final l = languageForRegion(country: entry.key, currency: entry.value);
        // USD/EUR sin país conocido en el mapa darían null: se acepta, pero no debe romper.
        if (l != null) expect(kLanguageNames.containsKey(l), isTrue, reason: entry.key);
      }
    });
  });

  group('respuesta de la API de país', () {
    test('country.is', () {
      expect(parseCountryCode('{"ip":"1.2.3.4","country":"pe"}', 'country'), 'PE');
    });
    test('ipwho.is', () {
      expect(parseCountryCode('{"success":true,"country_code":"BR"}', 'country_code'), 'BR');
    });
    test('respuestas inválidas', () {
      expect(parseCountryCode('no es json', 'country'), isNull);
      expect(parseCountryCode('{"country":"PERU"}', 'country'), isNull);
      expect(parseCountryCode('{}', 'country'), isNull);
      expect(parseCountryCode('[1,2]', 'country'), isNull);
    });
  });
}
