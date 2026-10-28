import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_config.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../services/biometric_service.dart';
import '../services/feedback_service.dart';
import '../services/notification_service.dart';
import '../services/quick_actions_service.dart';
import '../services/receipt_ocr_service.dart';
import '../widgets/section_card.dart';

/// Pantalla para reportar un fallo, sugerir una mejora o hacer una pregunta.
/// El mensaje llega al desarrollador por Telegram. Nunca se envían gastos,
/// ingresos ni montos: solo lo que el usuario escribe y, si lo marca, datos
/// técnicos del teléfono (que se muestran antes de enviar).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  String _type = 'bug';
  bool _includeTech = true;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  /// Datos técnicos que se enviarían (se muestran en la vista previa).
  Map<String, Object> _techInfo(LocaleProvider locale) {
    final String version = Platform.version;
    String os = Platform.operatingSystemVersion;
    if (os.length > 40) os = os.substring(0, 40);
    return {
      'so': os,
      'arq': version.contains('arm64') ? 'arm64' : (version.contains('arm') ? 'arm' : 'otra'),
      'idioma': locale.languageCode,
      'ocr': ReceiptOcrService.isAvailable,
      'huella': BiometricService.isAvailable,
      'avisos': NotificationService.isAvailable,
      'atajos': QuickActionsService.isAvailable,
    };
  }

  String _previewText(LocaleProvider locale) {
    final StringBuffer b = StringBuffer()
      ..writeln('${locale.t('reporte_tipo')}: ${locale.t('reporte_tipo_$_type')}')
      ..writeln('${locale.t('reporte_version')}: $kAppVersion (build $kAppBuild)')
      ..writeln()
      ..writeln(_messageController.text.trim().isEmpty ? '…' : _messageController.text.trim());
    if (_contactController.text.trim().isNotEmpty) {
      b.writeln('\n${locale.t('reporte_contacto')}: ${_contactController.text.trim()}');
    }
    if (_includeTech) {
      b.writeln('\n${locale.t('reporte_datos_tecnicos')}:');
      _techInfo(locale).forEach((k, v) => b.writeln('  $k: $v'));
    }
    return b.toString().trim();
  }

  Future<void> _shareInstead(LocaleProvider locale) async {
    await Share.share(_previewText(locale), subject: '$kAppName $kAppVersion');
  }

  Future<void> _send() async {
    final locale = context.read<LocaleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final String message = _messageController.text.trim();
    if (message.length < 5) {
      messenger.showSnackBar(SnackBar(content: Text(locale.t('reporte_mensaje_corto'))));
      return;
    }

    // Sin envío directo configurado: se ofrece el menú de compartir.
    if (!FeedbackService.isConfigured) {
      await _shareInstead(locale);
      return;
    }

    setState(() => _sending = true);
    final FeedbackStatus status = await FeedbackService(context.read<FinanceProvider>().settingsBox).send(
      FeedbackPayload(
        type: _type,
        message: message,
        contact: _contactController.text,
        tech: _includeTech ? _techInfo(locale) : const {},
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);

    switch (status) {
      case FeedbackStatus.sent:
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(locale.t('reporte_enviado'))));
        break;
      case FeedbackStatus.queued:
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(locale.t('reporte_en_cola'))));
        break;
      case FeedbackStatus.tooSoon:
        messenger.showSnackBar(SnackBar(content: Text(locale.t('reporte_muy_pronto'))));
        break;
      case FeedbackStatus.dailyLimit:
        messenger.showSnackBar(SnackBar(content: Text(locale.t('reporte_limite_diario'))));
        break;
      case FeedbackStatus.notConfigured:
        await _shareInstead(locale);
        break;
      case FeedbackStatus.rejected:
        messenger.showSnackBar(SnackBar(
          content: Text(locale.t('reporte_rechazado')),
          action: SnackBarAction(label: locale.t('reporte_compartir'), onPressed: () => _shareInstead(locale)),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(locale.t('reportar_titulo'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          Text(locale.t('reportar_ayuda'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'bug', label: Text(locale.t('reporte_tipo_bug'), style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 'idea', label: Text(locale.t('reporte_tipo_idea'), style: const TextStyle(fontSize: 12))),
              ButtonSegment(value: 'question', label: Text(locale.t('reporte_tipo_question'), style: const TextStyle(fontSize: 12))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _messageController,
            maxLines: 7,
            minLines: 5,
            maxLength: 1500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: locale.t('reporte_mensaje'),
              hintText: _type == 'bug' ? locale.t('reporte_pista_bug') : locale.t('reporte_pista_idea'),
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            maxLength: 120,
            decoration: InputDecoration(labelText: locale.t('reporte_contacto_opcional')),
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(locale.t('reporte_incluir_tecnicos')),
            subtitle: Text(locale.t('reporte_incluir_tecnicos_ayuda'), style: theme.textTheme.bodySmall),
            value: _includeTech,
            onChanged: (v) => setState(() => _includeTech = v),
          ),
          SectionCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(locale.t('reporte_ver_lo_que_se_envia'), style: theme.textTheme.bodyMedium),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(_previewText(locale), style: theme.textTheme.bodySmall),
                ),
                const SizedBox(height: 8),
                Text(locale.t('reporte_privacidad'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(FeedbackService.isConfigured ? Icons.send_rounded : Icons.ios_share_rounded),
            label: Text(FeedbackService.isConfigured ? locale.t('reporte_enviar') : locale.t('reporte_compartir')),
          ),
          if (!FeedbackService.isConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(locale.t('reporte_sin_envio_directo'), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
