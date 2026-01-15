import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'providers/app_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/production_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/transfers_provider.dart';

import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => ProductionProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => TransfersProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdminHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('es', 'ES'), 
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  void _initApp() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 1. Cargamos configuración guardada
    await appProvider.loadConfig();

    // 2. Lógica específica para WEB (Primer uso)
    if (kIsWeb && !appProvider.isConfigured) {
      print("🌐 Web (Primer Uso): Aplicando configuración por defecto...");
      await appProvider.updateConfig("http://192.168.1.80:3000", "marquez", ""); 
    }

    // 3. ¡LISTO! Ahora sí permitimos que se dibuje la interfaz
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Una vez listo, procedemos normal
    final appProvider = context.watch<AppProvider>();

    if (kIsWeb) {
      if (!appProvider.isWebLoggedIn) {
        return const LoginScreen();
      }
    }

    return const DashboardScreen();
  }
}

//WAWA await appProvider.updateConfig("https://programastablet.ddns.net:3000", "marquez", "");