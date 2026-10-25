import 'package:url_launcher/url_launcher.dart';

/// Abre enlaces en el navegador. Es el ÚNICO archivo que importa url_launcher;
/// si el plugin diera problemas, el workflow lo reemplaza por
/// `tool/lite/url_service.dart` (misma API; la app copia el enlace en su lugar).
class UrlService {
  static const bool isAvailable = true;

  /// `true` si se pudo abrir el enlace.
  Future<bool> open(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
