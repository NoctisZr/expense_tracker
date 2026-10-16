import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../utils/app_theme_extension.dart';
import '../widgets/mod_overlay.dart';
import '../widgets/onboarding_dialog.dart';
import 'converter_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'shipping_calculator_screen.dart';

/// Contenedor principal: BottomNavigationBar con las 4 pestañas. Si hay
/// una imagen de fondo personalizada, se dibuja detrás del contenido.
/// Por encima de TODO (incluyendo las tarjetas) se dibuja la "máscara"
/// que pueda pedir un mod activo — un patrón liviano o una imagen
/// propia — con `IgnorePointer` para no bloquear ningún toque.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    ConverterScreen(),
    ShippingCalculatorScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOnboarding();
      _runAutoBackupIfDue();
    });
  }

  /// La bienvenida solo se muestra en una instalación nueva (sin datos). A
  /// quien actualiza desde una versión anterior (ya tiene datos) se le
  /// marca como vista sin mostrarla.
  Future<void> _maybeShowOnboarding() async {
    if (!mounted) return;
    final finance = context.read<FinanceProvider>();
    if (finance.settingsBox.get('onboardingDone') == true) return;
    final bool hasData = finance.expensesBox.isNotEmpty ||
        finance.incomesBox.isNotEmpty ||
        finance.vaultsBox.isNotEmpty;
    await finance.settingsBox.put('onboardingDone', true);
    if (hasData || !mounted) return;
    await showOnboardingDialog(context);
  }

  /// Respaldo automático local (máximo uno cada 7 días por espacio de
  /// trabajo, y solo si hay datos). Se guardan los últimos 5.
  Future<void> _runAutoBackupIfDue() async {
    if (!mounted) return;
    final finance = context.read<FinanceProvider>();
    final String key = 'lastAutoBackup_${finance.activeWorkspaceId}';
    final DateTime? last = DateTime.tryParse((finance.settingsBox.get(key) as String?) ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(days: 7)) return;
    final bool hasData = finance.expensesBox.isNotEmpty ||
        finance.incomesBox.isNotEmpty ||
        finance.vaultsBox.isNotEmpty;
    if (!hasData) return;
    try {
      await BackupService().writeAutoBackup(finance.activeWorkspaceId, finance.exportData());
      await finance.settingsBox.put(key, DateTime.now().toIso8601String());
    } catch (_) {
      // Un fallo del respaldo automático nunca debe molestar al usuario.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app se refrescan las tasas de cambio (como máximo una
  /// vez por hora) y se registran los gastos recurrentes que ya vencieron.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    context.read<CurrencyProvider>().refreshIfStale();
    final finance = context.read<FinanceProvider>();
    if (finance.applyRecurringExpenses() > 0) {
      finance.notifyChanged();
    }
    _runAutoBackupIfDue();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;
    final String? backgroundPath = themeProvider.backgroundImagePath;
    final bool hasBackground = backgroundPath != null && File(backgroundPath).existsSync();

    return Scaffold(
      backgroundColor: hasBackground ? Colors.transparent : null,
      extendBody: hasBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBackground) ...[
            Image.file(File(backgroundPath), fit: BoxFit.cover),
            Container(color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72)),
          ],
          IndexedStack(index: _currentIndex, children: _screens),
          ModOverlay(
            pattern: extras.overlayPattern,
            opacity: extras.overlayOpacity,
            color: extras.cornerAccentColor,
            imageBase64: extras.overlayImageBase64,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: theme.colorScheme.surface,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet),
            label: locale.t('nav_presupuesto'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.currency_exchange_outlined),
            activeIcon: const Icon(Icons.currency_exchange),
            label: locale.t('nav_conversor'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.local_shipping_outlined),
            activeIcon: const Icon(Icons.local_shipping),
            label: locale.t('nav_envios'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: locale.t('nav_ajustes'),
          ),
        ],
      ),
    );
  }
}
