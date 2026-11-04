/// Versión "lite" (sin open_filex) de ApkInstaller: misma API, pero no instala
/// nada (la app abre el enlace de descarga en el navegador). Solo se usa si el
/// build completo falla.
enum InstallOutcome { opened, permissionNeeded, failed, unsupported }

class ApkInstaller {
  static const bool isAvailable = false;

  Future<InstallOutcome> install(String path) async => InstallOutcome.unsupported;
}
