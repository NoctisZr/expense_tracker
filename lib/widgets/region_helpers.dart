import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../utils/region_defaults.dart';

/// Si la [currency] elegida suele usarse con otro idioma de la app, ofrece
/// cambiarlo (sin forzar nada).
void maybeSuggestLanguage(BuildContext context, String currency) {
  final locale = context.read<LocaleProvider>();
  final String? suggested = languageForRegion(currency: currency);
  if (suggested == null || suggested == locale.languageCode) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 8),
    content: Text(locale.t('sugerir_idioma').replaceAll('{l}', kLanguageNames[suggested] ?? suggested)),
    action: SnackBarAction(
      label: locale.t('cambiar_idioma_btn'),
      onPressed: () => locale.setLanguage(suggested),
    ),
  ));
}
