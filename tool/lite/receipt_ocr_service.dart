/// Versión "lite" (sin ML Kit) de ReceiptOcrService: misma API, pero sin
/// reconocimiento de texto. Solo se usa si el build completo falla.
class ReceiptOcrService {
  static const bool isAvailable = false;

  Future<String> recognizeText(String imagePath) async {
    throw UnsupportedError('OCR no disponible en esta compilación.');
  }
}
