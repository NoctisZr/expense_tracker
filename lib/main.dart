import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/expense.dart';
import 'models/income.dart';
import 'models/vault.dart';
import 'models/vault_transaction.dart';
import 'providers/currency_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/security_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'utils/app_theme.dart';
import 'widgets/pin_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
    // Los typeId son fijos (0 Expense, 1 Vault, 2 VaultTransaction,
    // 3 Income): cada adaptador se registra por su propio typeId.
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(VaultAdapter());
    Hive.registerAdapter(VaultTransactionAdapter());
    Hive.registerAdapter(IncomeAdapter());

    // Se conservan los nombres de caja originales: los datos de la
    // versión anterior siguen disponibles.
    final Box settingsBox = await Hive.openBox('settings_box');
    final FinanceProvider financeProvider = await FinanceProvider.create(settingsBox);

    runApp(
      ExpenseTrackerApp(
        financeProvider: financeProvider,
        settingsBox: settingsBox,
      ),
    );
  } catch (e, stackTrace) {
    runApp(_StartupErrorApp(error: e, stackTrace: stackTrace));
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
        // lazy: false para que el bloqueo por PIN exista desde el primer frame.
        ChangeNotifierProvider(create: (_) => SecurityProvider(settingsBox), lazy: false),
        ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Expense Tracker',
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
                  textScaler: TextScaler.linear(systemScale * themeProvider.textScale),
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
