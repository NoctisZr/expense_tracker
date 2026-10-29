import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'app_config.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'models/vault.dart';
import 'models/vault_transaction.dart';
import 'providers/currency_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/security_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'widgets/pin_widgets.dart';

/// Resultado de la inicialización pesada (base de datos y providers).
class _BootResult {
  final Box settingsBox;
  final FinanceProvider finance;

  const _BootResult(this.settingsBox, this.finance);
}

/// Abre la base de datos. Corre DESPUÉS de dibujar la pantalla de carga, así
/// el usuario ve algo inmediatamente en lugar de una pantalla negra.
Future<_BootResult> _initialize() async {
  await Hive.initFlutter();
  // Los typeId son fijos (0 Expense, 1 Vault, 2 VaultTransaction,
  // 3 Income): cada adaptador se registra por su propio typeId.
  Hive.registerAdapter(ExpenseAdapter());
  Hive.registerAdapter(VaultAdapter());
  Hive.registerAdapter(VaultTransactionAdapter());
  Hive.registerAdapter(IncomeAdapter());

  // Se conservan los nombres de caja originales: los datos de la versión
  // anterior siguen disponibles.
  final Box settingsBox = await Hive.openBox('settings_box');
  // Las cuatro cajas del espacio activo se abren en paralelo.
  final FinanceProvider finance = await FinanceProvider.create(settingsBox);
  return _BootResult(settingsBox, finance);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Primer fotograma inmediato: pantalla de carga mientras se inicializa todo.
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  _BootResult? _result;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _initialize().then((result) {
      if (mounted) setState(() => _result = result);
    }).catchError((Object e, StackTrace st) {
      if (mounted) {
        setState(() {
          _error = e;
          _stackTrace = st;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _StartupErrorApp(error: _error!, stackTrace: _stackTrace ?? StackTrace.empty);
    }
    final _BootResult? result = _result;
    if (result == null) return const _SplashApp();
    return ExpenseTrackerApp(financeProvider: result.finance, settingsBox: result.settingsBox);
  }
}

/// Pantalla de carga mínima (sin providers ni base de datos). Usa el mismo
/// color que la ventana nativa de arranque para que no haya parpadeos.
class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    final bool dark = PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    final Color background = dark ? const Color(0xFF16171F) : const Color(0xFFF4F5F9);
    final Color foreground = dark ? const Color(0xFFE8E9F0) : const Color(0xFF22232B);
    const Color accent = Color(0xFF26C6A6);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 56, color: accent),
              const SizedBox(height: 14),
              Text(
                kAppName,
                style: TextStyle(color: foreground, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  final FinanceProvider financeProvider;
  final Box settingsBox;

  const ExpenseTrackerApp({
    super.key,
    required this.financeProvider,
    required this.settingsBox,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(settingsBox)),
        ChangeNotifierProvider(create: (_) => LocaleProvider(settingsBox)),
        ChangeNotifierProvider(create: (_) => CurrencyProvider(settingsBox)),
        ChangeNotifierProvider(create: (_) => UpdateProvider(settingsBox)),
        // lazy: false para que el bloqueo por PIN exista desde el primer frame.
        ChangeNotifierProvider(create: (_) => SecurityProvider(settingsBox), lazy: false),
        ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: kAppName,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(isDark: false, accent: themeProvider.accentColor, mod: themeProvider.activeMod),
            darkTheme: buildAppTheme(isDark: true, accent: themeProvider.accentColor, mod: themeProvider.activeMod),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              // Tamaño de texto del usuario multiplicado por el del sistema.
              final MediaQueryData mq = MediaQuery.of(context);
              final double systemScale = mq.textScaler.scale(14) / 14;
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(systemScale * themeProvider.effectiveTextScale),
                ),
                child: LockGate(child: child ?? const SizedBox.shrink()),
              );
            },
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

/// Pantalla de diagnóstico si algo falla al abrir la base de datos, en
/// lugar de quedarse en blanco.
class _StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stackTrace;

  const _StartupErrorApp({required this.error, required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF3B1010),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Text(
                'Error al iniciar la app:\n\n$error\n\n$stackTrace',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
