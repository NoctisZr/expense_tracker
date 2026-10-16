import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import 'currency_dropdown.dart';

/// Bienvenida de 3 pasos que solo ve quien abre la app por primera vez
/// (sin datos): idioma y moneda, recorrido por las secciones y consejos.
Future<void> showOnboardingDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OnboardingDialog(),
  );
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  int _step = 0;

  Widget _tourRow(IconData icon, String title, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text(text, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.watch<FinanceProvider>();
    final theme = Theme.of(context);

    final Widget body;
    switch (_step) {
      case 0:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(locale.t('onb_bienvenida_texto'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(locale.t('idioma')),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: locale.languageCode,
                    dropdownColor: theme.colorScheme.surface,
                    items: [
                      DropdownMenuItem(value: 'es', child: Text(locale.t('espanol'))),
                      DropdownMenuItem(value: 'en', child: Text(locale.t('ingles'))),
                      DropdownMenuItem(value: 'pt', child: Text(locale.t('portugues'))),
                    ],
                    onChanged: (value) {
                      if (value != null) context.read<LocaleProvider>().setLanguage(value);
                    },
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(locale.t('moneda_local')),
                CurrencyDropdown(
                  value: finance.localCurrency,
                  onChanged: (value) => finance.setLocalCurrency(value),
                ),
              ],
            ),
          ],
        );
        break;
      case 1:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tourRow(Icons.account_balance_wallet_outlined, locale.t('nav_presupuesto'), locale.t('onb_tour_presupuesto'), theme),
            _tourRow(Icons.swap_horiz_rounded, locale.t('nav_conversor'), locale.t('onb_tour_conversor'), theme),
            _tourRow(Icons.local_shipping_outlined, locale.t('nav_envios'), locale.t('onb_tour_envios'), theme),
            _tourRow(Icons.settings_outlined, locale.t('nav_ajustes'), locale.t('onb_tour_ajustes'), theme),
          ],
        );
        break;
      default:
        body = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tourRow(Icons.lock_outline_rounded, locale.t('seguridad'), locale.t('onb_consejo_pin'), theme),
            _tourRow(Icons.upload_file_rounded, locale.t('respaldo_y_datos'), locale.t('onb_consejo_respaldo'), theme),
            _tourRow(Icons.workspaces_outlined, locale.t('espacio_activo'), locale.t('onb_consejo_espacios'), theme),
          ],
        );
    }

    final String title = _step == 0
        ? locale.t('onb_bienvenida')
        : _step == 1
            ? locale.t('onb_recorrido')
            : locale.t('onb_consejos');

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: body),
      actions: [
        if (_step > 0)
          TextButton(
            onPressed: () => setState(() => _step--),
            child: Text(locale.t('onb_atras')),
          ),
        ElevatedButton(
          onPressed: () {
            if (_step < 2) {
              setState(() => _step++);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(_step < 2 ? locale.t('onb_siguiente') : locale.t('onb_empezar')),
        ),
      ],
    );
  }
}
