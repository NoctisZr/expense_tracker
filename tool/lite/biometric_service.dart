/// Versión "lite" (sin local_auth) de BiometricService: misma API, pero sin
/// biometría. Solo se usa si el build completo falla.
class BiometricService {
  static const bool isAvailable = false;

  Future<bool> canUse() async => false;

  Future<bool> authenticate(String reason) async => false;
}
