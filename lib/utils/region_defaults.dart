/// Idioma que le corresponde a cada país y a cada moneda. La app habla
/// español (es), inglés (en) y portugués (pt). Se usa para elegir el idioma
/// en el primer inicio cuando el del teléfono no está disponible, y para
/// sugerir el idioma cuando el usuario cambia su moneda local.

/// País (ISO 3166) -> idioma de la app.
const Map<String, String> kCountryLanguage = {
  // Español
  'ES': 'es', 'MX': 'es', 'AR': 'es', 'CL': 'es', 'CO': 'es', 'PE': 'es', 'VE': 'es',
  'UY': 'es', 'BO': 'es', 'PY': 'es', 'DO': 'es', 'GT': 'es', 'CR': 'es', 'PA': 'es',
  'EC': 'es', 'SV': 'es', 'PR': 'es', 'HN': 'es', 'NI': 'es', 'CU': 'es',
  // Portugués
  'BR': 'pt', 'PT': 'pt', 'AO': 'pt', 'MZ': 'pt',
  // Inglés (y países sin idioma propio en la app)
  'US': 'en', 'GB': 'en', 'CA': 'en', 'AU': 'en', 'IE': 'en', 'NZ': 'en', 'IN': 'en',
  'JP': 'en', 'CN': 'en', 'KR': 'en', 'CH': 'en', 'DE': 'en', 'FR': 'en', 'IT': 'en',
  'NL': 'en', 'BE': 'en', 'AT': 'en', 'FI': 'en', 'GR': 'en',
};

/// Moneda -> idioma. No incluye las monedas que se usan en varios idiomas
/// (USD, EUR, CHF): para esas manda el país.
const Map<String, String> kCurrencyLanguage = {
  'PEN': 'es', 'VES': 'es', 'MXN': 'es', 'ARS': 'es', 'CLP': 'es', 'COP': 'es',
  'UYU': 'es', 'BOB': 'es', 'PYG': 'es', 'DOP': 'es', 'GTQ': 'es', 'CRC': 'es', 'PAB': 'es',
  'BRL': 'pt',
  'GBP': 'en', 'CAD': 'en', 'AUD': 'en', 'INR': 'en', 'JPY': 'en', 'CNY': 'en', 'KRW': 'en',
};

/// Nombre de cada idioma en su propio idioma.
const Map<String, String> kLanguageNames = {
  'es': 'Español',
  'en': 'English',
  'pt': 'Português',
};

/// Idioma que corresponde a un [country] y/o una [currency]. El país manda;
/// la moneda es el respaldo. Null si no se puede determinar.
String? languageForRegion({String? country, String? currency}) {
  if (country != null) {
    final String? byCountry = kCountryLanguage[country.toUpperCase()];
    if (byCountry != null) return byCountry;
  }
  if (currency != null) return kCurrencyLanguage[currency.toUpperCase()];
  return null;
}
