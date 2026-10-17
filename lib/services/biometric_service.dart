import 'package:local_auth/local_auth.dart';

/// Desbloqueo con huella / biometría del teléfono.
///
/// Este es el ÚNICO archivo que importa local_auth. Si el plugin diera
/// problemas de compilación, el workflow lo reemplaza automáticamente por
/// `tool/lite/biometric_service.dart` (misma API, sin biometría).
class BiometricService {
  static const bool isAvailable = true;

  final LocalAuthentication _auth = LocalAuthentication();

  /// `true` si el teléfono tiene biometría configurada y disponible.
  Future<bool> canUse() async {
    try {
      final bool supported = await _auth.canCheckBiometrics;
      if (!supported) return false;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Pide la huella. Cualquier error (cancelado, sin configurar, plugin mal
  /// integrado...) devuelve `false` y la app sigue pidiendo el PIN.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
