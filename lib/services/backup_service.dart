import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupImportException implements Exception {
  final String message;
  BackupImportException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  Future<void> exportAndShare(Map<String, dynamic> data) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final File file = File('${tempDir.path}/expense_tracker_backup_$timestamp.json');
    final String jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Expense Tracker - Respaldo de datos',
    );
  }

  Future<void> exportCsvAndShare(String csv) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final File file = File('${tempDir.path}/expense_tracker_gastos_$timestamp.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Expense Tracker - Gastos (CSV)',
    );
  }

  Future<Map<String, dynamic>?> pickAndParseBackup() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    final String? path = result?.files.single.path;
    if (path == null) return null;

    late final String content;
    try {
      content = await File(path).readAsString();
    } catch (_) {
      throw BackupImportException('No se pudo leer el archivo seleccionado.');
    }

    late final dynamic decoded;
    try {
      decoded = json.decode(content);
    } catch (_) {
      throw BackupImportException('El archivo no contiene un JSON válido.');
    }

    if (decoded is! Map<String, dynamic> || decoded['formatVersion'] == null) {
      throw BackupImportException('El archivo no es un respaldo válido de esta app.');
    }

    return decoded;
  }
}
