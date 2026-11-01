import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Cifrado de extremo a extremo de la sincronización de pareja.
///
/// El código de invitación (12 caracteres, 60 bits) solo lo conocen los dos.
/// De él salen: (1) una "huella" que el servidor usa para dejar unirse a la
/// pareja y (2) la clave AES-256-GCM con la que se cifra cada dato en el
/// teléfono. El servidor solo ve texto cifrado.

// Sin 0, O, 1, I para no confundirlos al dictar el código.
const String kInviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int kInviteLength = 12;

/// Código nuevo, sin separadores (p. ej. "K7M29QXA4TBD").
String generateInviteCode([Random? random]) {
  final Random r = random ?? Random.secure();
  return List.generate(kInviteLength, (_) => kInviteAlphabet[r.nextInt(kInviteAlphabet.length)]).join();
}

/// Mayúsculas y sin separadores ni espacios.
String normalizeInviteCode(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool isValidInviteCode(String raw) {
  final String code = normalizeInviteCode(raw);
  return code.length == kInviteLength && code.split('').every(kInviteAlphabet.contains);
}

/// "K7M2-9QXA-4TBD" para mostrarlo en pantalla.
String formatInviteCode(String code) {
  final String c = normalizeInviteCode(code);
  if (c.length != kInviteLength) return c;
  return '${c.substring(0, 4)}-${c.substring(4, 8)}-${c.substring(8)}';
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Huella del código que se envía al servidor (nunca el código).
Future<String> inviteHash(String code) async {
  final Hash h = await Sha256().hash(utf8.encode('nuvio-join-v1:${normalizeInviteCode(code)}'));
  return _hex(h.bytes);
}

/// Clave de cifrado (32 bytes) derivada del código.
Future<List<int>> deriveCoupleKey(String code, {int iterations = 20000}) async {
  final Pbkdf2 pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
  final SecretKey key = await pbkdf2.deriveKeyFromPassword(
    password: normalizeInviteCode(code),
    nonce: utf8.encode('nuvio-couple-v1'),
  );
  return key.extractBytes();
}

/// Resultado de cifrar: texto cifrado (con la etiqueta de autenticación al
/// final) y el nonce, ambos en base64.
class SealedData {
  final String payload;
  final String nonce;
  const SealedData(this.payload, this.nonce);
}

const int _macLength = 16;

Future<SealedData> encryptJson(Map<String, dynamic> data, List<int> keyBytes) async {
  final SecretBox box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: SecretKey(keyBytes),
  );
  return SealedData(base64Encode([...box.cipherText, ...box.mac.bytes]), base64Encode(box.nonce));
}

/// Null si la clave no corresponde o el dato fue alterado.
Future<Map<String, dynamic>?> decryptJson(String payload, String nonce, List<int> keyBytes) async {
  try {
    final List<int> all = base64Decode(payload);
    if (all.length <= _macLength) return null;
    final SecretBox box = SecretBox(
      all.sublist(0, all.length - _macLength),
      nonce: base64Decode(nonce),
      mac: Mac(all.sublist(all.length - _macLength)),
    );
    final List<int> clear = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(keyBytes));
    final dynamic data = jsonDecode(utf8.decode(clear));
    return data is Map ? Map<String, dynamic>.from(data) : null;
  } catch (_) {
    return null;
  }
}

/// Huella corta y estable (FNV-1a de 2 x 32 bits) para detectar qué datos
/// cambiaron desde la última sincronización. No es criptográfica.
String changeHash(String text) {
  int a = 0x811c9dc5;
  int b = 0x01000193;
  for (final int unit in text.codeUnits) {
    a = ((a ^ unit) * 16777619) & 0xFFFFFFFF;
    b = ((b ^ unit) * 2166136261) & 0xFFFFFFFF;
  }
  return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
}
