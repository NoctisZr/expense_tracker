import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rate_alert.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import '../services/quick_actions_service.dart';
import '../utils/app_navigation.dart';
import '../utils/app_theme_extension.dart';
import '../utils/notification_planner.dart';
import '../widgets/mod_overlay.dart';
import '../widgets/onboarding_dialog.dart';
import '../widgets/receipt_flow.dart';
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

  /// Pestañas que ya se abrieron. Solo esas se construyen: antes las 4
  /// pestañas completas se dibujaban a la vez en el primer fotograma.
  final Set<int> _built = {0};

  Timer? _notifTimer;
  FinanceProvider? _finance;
  CurrencyProvider? _currency;

  String? _checkedBackgroundPath;
  bool _backgroundExists = false;

  Widget _screenFor(int index) {
    if (!_built.contains(index)) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ConverterScreen();
      case 2:
        return const ShippingCalculatorScreen();
      default:
        return const SettingsScreen();
    }
  }

  /// Comprueba si existe el archivo de fondo SOLO cuando cambia la ruta (antes
  /// se hacía una lectura de disco síncrona en cada reconstrucción).
  bool _backgroundFileExists(String? path) {
    if (path == null) return false;
    if (path != _checkedBackgroundPath) {
      _checkedBackgroundPath = path;
      _backgroundExists = File(path).existsSync();
    }
    return _backgroundExists;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Todo lo no esencial espera a que la primera pantalla ya esté dibujada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) context.read<FinanceProvider>().runStartupTasks();
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) context.read<CurrencyProvider>().refreshIfStale();
      });
      _maybeShowOnboarding();

      // Avisos programados, atajos de pantalla y alertas de tasas.
      _finance = context.read<FinanceProvider>()..addListener(_onFinanceChanged);
      _currency = context.read<CurrencyProvider>()..onAlertsFired = _onRateAlerts;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _setupQuickActions();
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _scheduleNotifications();
      });

      Future.delayed(const Duration(seconds: 12), () {
        if (mounted) _runAutoBackupIfDue();
      });
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
    _notifTimer?.cancel();
    _finance?.removeListener(_onFinanceChanged);
    _currency?.onAlertsFired = null;
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
    _scheduleNotifications();
  }

  /// Los avisos se vuelven a agendar poco después de cualquier cambio en los
  /// datos (con una pausa para no hacerlo en cada tecla).
  void _onFinanceChanged() {
    _notifTimer?.cancel();
    _notifTimer = Timer(const Duration(seconds: 6), _scheduleNotifications);
  }

  void _scheduleNotifications() {
    if (!mounted) return;
    rescheduleNotifications(
      finance: context.read<FinanceProvider>(),
      locale: context.read<LocaleProvider>(),
    );
  }

  void _setupQuickActions() {
    if (!QuickActionsService.isAvailable) return;
    final locale = context.read<LocaleProvider>();
    try {
      QuickActionsService().setup(
        titles: {
          'add_expense': locale.t('atajo_anadir_gasto'),
          'scan_receipt': locale.t('atajo_escanear'),
          'converter': locale.t('atajo_conversor'),
        },
        onAction: _onQuickAction,
      );
    } catch (_) {}
  }

  void _onQuickAction(String type) {
    if (!mounted) return;
    switch (type) {
      case 'add_expense':
        setState(() {
          _currentIndex = 0;
          _built.add(0);
        });
        AppNavigation.dashboardView.value = 1;
        break;
      case 'scan_receipt':
        setState(() {
          _currentIndex = 0;
          _built.add(0);
        });
        AppNavigation.dashboardView.value = 1;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) startReceiptScan(context);
        });
        break;
      case 'converter':
        setState(() {
          _currentIndex = 1;
          _built.add(1);
        });
        break;
    }
  }

  /// Se cumplió una alerta de tasa: aviso dentro de la app y, si las
  /// notificaciones están activas, también como notificación.
  void _onRateAlerts(List<RateAlert> alerts) {
    if (!mounted) return;
    final locale = context.read<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final bool notify = NotificationService.isAvailable &&
        NotificationPrefs.load(finance.settingsBox).enabled;
    for (int i = 0; i < alerts.length; i++) {
      final RateAlert a = alerts[i];
      final String text = '1 ${a.from} ${a.above ? '≥' : '≤'} ${a.target} ${a.to}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${locale.t('alerta_cumplida')}: $text')),
      );
      if (notify) {
        NotificationService()
            .showNow(id: 9000 + i, title: locale.t('alerta_cumplida'), body: text)
            .catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;
    final String? backgroundPath = themeProvider.backgroundImagePath;
    final bool hasBackground = _backgroundFileExists(backgroundPath);

    return Scaffold(
      backgroundColor: hasBackground ? Colors.transparent : null,
      extendBody: hasBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBackground) ...[
            Image.file(File(backgroundPath!), fit: BoxFit.cover),
            Container(color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72)),
          ],
          IndexedStack(
            index: _currentIndex,
            children: [for (int i = 0; i < 4; i++) _screenFor(i)],
          ),
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
        onTap: (index) => setState(() {
          _currentIndex = index;
          _built.add(index);
        }),
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
