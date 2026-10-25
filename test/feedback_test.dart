import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/app_config.dart';
import 'package:expense_tracker/services/feedback_service.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 22, 12);

  group('límites locales', () {
    test('sin envíos previos se puede enviar', () {
      expect(FeedbackService.checkLimit(const [], now), isNull);
    });

    test('1 por minuto', () {
      expect(
        FeedbackService.checkLimit([now.subtract(const Duration(seconds: 30))], now),
        FeedbackStatus.tooSoon,
      );
      expect(
        FeedbackService.checkLimit([now.subtract(const Duration(minutes: 5))], now),
        isNull,
      );
    });

    test('10 en 24 horas', () {
      final ten = [for (int i = 1; i <= 10; i++) now.subtract(Duration(minutes: 5 * i))];
      expect(FeedbackService.checkLimit(ten, now), FeedbackStatus.dailyLimit);
    });

    test('los envíos de hace más de 24 horas no cuentan', () {
      final old = [for (int i = 0; i < 12; i++) now.subtract(Duration(hours: 25 + i))];
      expect(FeedbackService.checkLimit(old, now), isNull);
    });
  });

  test('el payload incluye versión y build y recorta el mensaje', () {
    const payload = FeedbackPayload(
      type: 'idea',
      message: '  Quiero modo claro automático  ',
      contact: ' a@b.com ',
      tech: {'arq': 'arm64', 'ocr': true},
    );
    final json = payload.toJson();
    expect(json['type'], 'idea');
    expect(json['message'], 'Quiero modo claro automático');
    expect(json['contact'], 'a@b.com');
    expect(json['version'], kAppVersion);
    expect(json['build'], kAppBuild);
    expect((json['tech'] as Map)['ocr'], true);
  });
}
