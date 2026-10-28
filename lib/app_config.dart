// GENERADO por tool/gen_app_config.py (en CI se regenera en cada build).
// Los valores de repositorio y reportes salen de variables de GitHub Actions.

/// Nombre de la app (viene de tool/app_name.txt: el único sitio donde se cambia).
const String kAppName = 'Peculio';

/// Versión de la app (viene de pubspec.yaml).
const String kAppVersion = '1.7.0';

/// Número de build (lo que va después del "+" en pubspec.yaml).
const int kAppBuild = 13;

/// "owner/nombre" del repositorio de GitHub donde se publican los releases.
/// Vacío = sin comprobación de actualizaciones.
const String kGithubRepo = '';

/// URL del Worker que reenvía los reportes a Telegram. Vacío = sin envío directo.
const String kFeedbackUrl = '';

/// Clave que se envía en la cabecera X-App-Key (no es secreta: solo frena el spam casual).
const String kFeedbackAppKey = '';
