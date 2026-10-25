import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';

/// Lo que el usuario quiere enviar. Nunca incluye gastos ni montos.
class FeedbackPayload {
  /// 'bug' | 'idea' | 'question'
  final String type;
  final String message;
  final String contact;
  final Map<String, Object> tech;

  const FeedbackPayload({
    required this.type,
    required this.message,
    this.contact = '',
    this.tech = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'message': message.trim(),
        'contact': contact.trim(),
        'version': kAppVersion,
        'build': kAppBuild,
        'tech': tech,
      };
}

enum FeedbackStatus {
  /// Enviado y recibido.
  sent,

  /// Sin conexión (o error del servidor): se guardó y se reintentará solo.
  queued,

  /// La app no tiene configurado el envío directo.
  notConfigured,

  /// Demasiado pronto desde el último envío (1 por minuto).
  tooSoon,

  /// Se llegó al máximo diario (10).
  dailyLimit,

  /// El servidor rechazó el reporte (clave, formato o límite).
  rejected,
}

/// Envía reportes al Worker que los reenvía a Telegram. Guarda los que no
/// pudo enviar (máx. 5) y los reintenta después.
class FeedbackService {
  static const String _logKey = 'feedbackLog';
  static const String _pendingKey = 'pendingFeedback';
  static const int _maxPending = 5;

  final Box box;
  const FeedbackService(this.box);

  static bool get isConfigured => kFeedbackUrl.isNotEmpty;

  /// Límites locales (función pura para poder probarla): 1 por minuto y 10
  /// cada 24 horas. `null` = se puede enviar.
  static FeedbackStatus? checkLimit(List<DateTime> sentLog, DateTime now) {
    final List<DateTime> lastDay =
        sentLog.where((t) => now.difference(t) < const Duration(hours: 24)).toList();
    if (lastDay.any((t) => now.difference(t) < const Duration(seconds: 60))) {
      return FeedbackStatus.tooSoon;
    }
    if (lastDay.length >= 10) return FeedbackStatus.dailyLimit;
    return null;
  }

  List<DateTime> _readLog() {
    final dynamic raw = box.get(_logKey);
    if (raw is! List) return [];
    return raw.map((e) => DateTime.tryParse(e.toString())).whereType<DateTime>().toList();
  }

  Future<void> _recordSent() async {
    final DateTime now = DateTime.now();
    final List<String> log = [
      ..._readLog().where((t) => now.difference(t) < const Duration(hours: 24)).map((t) => t.toIso8601String()),
      now.toIso8601String(),
    ];
    await box.put(_logKey, log);
  }

  Future<FeedbackStatus> send(FeedbackPayload payload) async {
    if (!isConfigured) return FeedbackStatus.notConfigured;
    final FeedbackStatus? limit = checkLimit(_readLog(), DateTime.now());
    if (limit != null) return limit;

    final _Outcome outcome = await _post(payload.toJson());
    switch (outcome) {
      case _Outcome.ok:
        await _recordSent();
        return FeedbackStatus.sent;
      case _Outcome.retry:
        await _enqueue(payload.toJson());
        return FeedbackStatus.queued;
      case _Outcome.rejected:
        return FeedbackStatus.rejected;
    }
  }

  Future<_Outcome> _post(Map<String, dynamic> body) async {
    try {
      final http.Response response = await http
          .post(
            Uri.parse(kFeedbackUrl),
            headers: {
              'content-type': 'application/json',
              if (kFeedbackAppKey.isNotEmpty) 'X-App-Key': kFeedbackAppKey,
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) return _Outcome.ok;
      if (response.statusCode >= 500) return _Outcome.retry;
      return _Outcome.rejected;
    } catch (_) {
      return _Outcome.retry;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> body) async {
    final dynamic raw = box.get(_pendingKey);
    final List<String> pending = raw is List ? raw.map((e) => e.toString()).toList() : [];
    pending.add(json.encode(body));
    while (pending.length > _maxPending) {
      pending.removeAt(0);
    }
    await box.put(_pendingKey, pending);
  }

  /// Reintenta los reportes guardados. Se llama poco después de abrir la app.
  Future<void> flushPending() async {
    if (!isConfigured) return;
    final dynamic raw = box.get(_pendingKey);
    if (raw is! List || raw.isEmpty) return;
    final List<String> remaining = [];
    for (final item in raw) {
      try {
        final _Outcome outcome = await _post(Map<String, dynamic>.from(json.decode(item.toString()) as Map));
        if (outcome == _Outcome.retry) remaining.add(item.toString());
      } catch (_) {
        // un reporte ilegible se descarta
      }
    }
    if (remaining.isEmpty) {
      await box.delete(_pendingKey);
    } else {
      await box.put(_pendingKey, remaining);
    }
  }
}

enum _Outcome { ok, retry, rejected }
