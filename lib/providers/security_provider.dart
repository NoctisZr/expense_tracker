import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/biometric_service.dart';

/// Bloqueo opcional de la app con un PIN de 4 dígitos. El PIN nunca se
/// guarda: solo un hash SHA-256 con sal aleatoria. Si hay PIN, la app se
/// bloquea al abrirse y al volver tras más de [lockAfter] en segundo plano.
class SecurityProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _hashKey = 'pinHash';
  static const String _saltKey = 'pinSalt';
  static const String _biometricKey = 'biometricEnabled';
  static const int pinLength = 4;
  static const Duration lockAfter = Duration(seconds: 30);
  static const int _maxAttempts = 5;
  static const Duration _blockDuration = Duration(seconds: 30);

  final Box settingsBox;

  late bool _locked;
  DateTime? _pausedAt;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;

  SecurityProvider(this.settingsBox) {
    _locked = hasPin;
    WidgetsBinding.instance.addObserver(this);
  }

  bool get hasPin => settingsBox.get(_hashKey) is String;
  bool get isLocked => _locked && hasPin;

  /// `true` si el usuario activó el desbloqueo con huella (requiere PIN).
  bool get biometricEnabled =>
      hasPin && BiometricService.isAvailable && settingsBox.get(_biometricKey, defaultValue: false) == true;

  Future<void> setBiometricEnabled(bool value) async {
    await settingsBox.put(_biometricKey, value);
    notifyListeners();
  }

  /// Pide la huella y, si es correcta, desbloquea la app.
  Future<bool> unlockWithBiometrics(String reason) async {
    if (!biometricEnabled) return false;
    final bool ok = await BiometricService().authenticate(reason);
    if (ok) {
      _failedAttempts = 0;
      _blockedUntil = null;
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Segundos que faltan para poder reintentar tras demasiados errores.
  int get blockedSeconds {
    final DateTime? until = _blockedUntil;
    if (until == null) return 0;
    final int left = until.difference(DateTime.now()).inSeconds + 1;
    return left > 0 ? left : 0;
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final Random random = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  bool verifyPin(String pin) {
    final dynamic hash = settingsBox.get(_hashKey);
    final dynamic salt = settingsBox.get(_saltKey);
    if (hash is! String || salt is! String) return false;
    return _hash(salt, pin) == hash;
  }

  /// Intenta desbloquear. Devuelve `false` si el PIN es incorrecto o si
  /// hay un bloqueo temporal por demasiados intentos.
  bool unlock(String pin) {
    if (blockedSeconds > 0) {
      notifyListeners();
      return false;
    }
    if (verifyPin(pin)) {
      _failedAttempts = 0;
      _blockedUntil = null;
      _locked = false;
      notifyListeners();
      return true;
    }
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _failedAttempts = 0;
      _blockedUntil = DateTime.now().add(_blockDuration);
    }
    notifyListeners();
    return false;
  }

  Future<void> setPin(String pin) async {
    final String salt = _newSalt();
    await settingsBox.put(_saltKey, salt);
    await settingsBox.put(_hashKey, _hash(salt, pin));
    _locked = false;
    notifyListeners();
  }

  Future<void> removePin() async {
    await settingsBox.delete(_hashKey);
    await settingsBox.delete(_saltKey);
    await settingsBox.delete(_biometricKey);
    _locked = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final DateTime? pausedAt = _pausedAt;
      _pausedAt = null;
      if (hasPin && pausedAt != null && DateTime.now().difference(pausedAt) > lockAfter) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
