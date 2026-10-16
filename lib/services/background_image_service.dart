import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

const int _maxDimension = 1080;
const int _blurRadius = 14;
const String _backgroundFileName = 'custom_background.jpg';

class BackgroundImageService {
  Future<String> processAndSave(Uint8List rawBytes) async {
    final Uint8List processed = await compute(_processImage, rawBytes);
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/$_backgroundFileName');
    await file.writeAsBytes(processed, flush: true);
    return file.path;
  }

  Future<void> deleteBackgroundFile(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

Uint8List _processImage(Uint8List rawBytes) {
  final img.Image? decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw const FormatException('No se pudo leer la imagen seleccionada.');
  }

  final bool isLandscape = decoded.width >= decoded.height;
  final img.Image resized = isLandscape
      ? img.copyResize(
          decoded,
          width: decoded.width > _maxDimension ? _maxDimension : decoded.width,
        )
      : img.copyResize(
          decoded,
          height: decoded.height > _maxDimension ? _maxDimension : decoded.height,
        );

  final img.Image blurred = img.gaussianBlur(resized, radius: _blurRadius);
  return Uint8List.fromList(img.encodeJpg(blurred, quality: 80));
}
