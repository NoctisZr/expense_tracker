import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reconocimiento de texto (OCR) en el propio teléfono con Google ML Kit:
/// funciona sin internet y la foto no sale del dispositivo.
///
/// Este es el ÚNICO archivo que importa ML Kit. Si el plugin llegara a dar
/// problemas de compilación, el workflow lo reemplaza automáticamente por
/// `tool/lite/receipt_ocr_service.dart` (misma API, sin OCR).
class ReceiptOcrService {
  static const bool isAvailable = true;

  /// Devuelve el texto reconocido en la imagen ubicada en [imagePath].
  Future<String> recognizeText(String imagePath) async {
    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
