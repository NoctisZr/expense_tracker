import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

/// Tutorial de 4 pantallas que se muestra al activar las finanzas en pareja
/// (y se puede volver a abrir desde los ajustes de la pestaña Pareja).
Future<void> showCoupleTutorial(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog.fullscreen(child: _CoupleTutorial()),
  );
}

class _CoupleTutorial extends StatefulWidget {
  const _CoupleTutorial();

  @override
  State<_CoupleTutorial> createState() => _CoupleTutorialState();
}

class _CoupleTutorialState extends State<_CoupleTutorial> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<IconData> _icons = [
    Icons.favorite_rounded,
    Icons.tune_rounded,
    Icons.call_split_rounded,
    Icons.lock_rounded,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final bool last = _page == _icons.length - 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(locale.t('pa_saltar')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _icons.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icons[i], size: 54, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      locale.t('pa_tut${i + 1}_t'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      locale.t('pa_tut${i + 1}_d'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _icons.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? theme.colorScheme.primary : theme.hintColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (last) {
                    Navigator.of(context).pop();
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                  }
                },
                child: Text(last ? locale.t('pa_entendido') : locale.t('pa_siguiente')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
