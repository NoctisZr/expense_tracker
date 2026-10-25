/// Versión "lite" (sin url_launcher) de UrlService: misma API, pero no abre
/// nada (la app copia el enlace al portapapeles). Solo se usa si el build
/// completo falla.
class UrlService {
  static const bool isAvailable = false;

  Future<bool> open(String url) async => false;
}
