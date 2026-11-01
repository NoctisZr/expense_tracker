import 'dart:convert';
import 'package:http/http.dart' as http;

/// Extrae un código de país de 2 letras (en mayúsculas) de la respuesta JSON
/// de un servicio de geolocalización por IP. Null si no es válido.
String? parseCountryCode(String body, String key) {
  try {
    final dynamic data = jsonDecode(body);
    if (data is! Map) return null;
    final String value = (data[key] ?? '').toString().trim();
    return RegExp(r'^[A-Za-z]{2}$').hasMatch(value) ? value.toUpperCase() : null;
  } catch (_) {
    return null;
  }
}

/// Deduce el país del usuario a partir de su IP, una sola vez en el primer
/// inicio. Solo se obtiene el código de país (la IP no se guarda). Usa
/// servicios gratuitos sin clave y prueba el siguiente si uno falla.
class RegionService {
  static const List<(String, String)> _sources = [
    ('https://api.country.is/', 'country'),
    ('https://ipwho.is/', 'country_code'),
  ];

  Future<String?> detectCountry({Duration timeout = const Duration(seconds: 5)}) async {
    for (final (String url, String key) in _sources) {
      try {
        final http.Response response = await http.get(Uri.parse(url)).timeout(timeout);
        if (response.statusCode != 200) continue;
        final String? code = parseCountryCode(response.body, key);
        if (code != null) return code;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
