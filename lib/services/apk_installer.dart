import 'package:open_filex/open_filex.dart';

enum InstallOutcome { opened, permissionNeeded, failed, unsupported }

/// Abre el instalador de Android con el APK ya descargado. Es el ÚNICO archivo
/// que importa `open_filex`; si el plugin diera problemas al compilar, el
/// workflow lo reemplaza por `tool/lite/apk_installer.dart` (misma API; la app
/// abre el enlace de descarga en el navegador).
class ApkInstaller {
  static const bool isAvailable = true;

  Future<InstallOutcome> install(String path) async {
    try {
      final OpenResult result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
      switch (result.type) {
        case ResultType.done:
          return InstallOutcome.opened;
        case ResultType.permissionDenied:
          return InstallOutcome.permissionNeeded;
        default:
          return InstallOutcome.failed;
      }
    } catch (_) {
      return InstallOutcome.failed;
    }
  }
}
