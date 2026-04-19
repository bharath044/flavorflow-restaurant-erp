import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/server_config.dart';
import 'services/api_service.dart';
import 'providers/product_provider.dart';
import 'providers/category_provider.dart';
import 'providers/order_provider.dart';
import 'providers/kitchen_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/inventory_provider.dart';
import 'services/invoice_provider.dart';
import 'services/auth_provider.dart' as app_auth;

import 'screens/role_select_screen.dart';
import 'screens/customer_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Init Hive (REQUIRED for AuthProvider)
  await Hive.initFlutter();
  await Hive.openBox('auth');

  // 2. Init Supabase
  await Supabase.initialize(
    url: ServerConfig.supabaseUrl,
    anonKey: ServerConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => KitchenProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
      ],
      child: MaterialApp(
        title: 'FlavorFlow Restaurant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFFFF6A00),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          useMaterial3: true,
        ),
        onGenerateRoute: (settings) {
          // 🚀 Handle Customer Menu /menu/T1
          if (settings.name != null && settings.name!.startsWith('/menu/')) {
            final tableNo = settings.name!.replaceFirst('/menu/', '');
            return MaterialPageRoute(
              builder: (context) => CustomerMenuScreen(tableNo: tableNo),
              settings: settings,
            );
          }
          
          // 🚀 Admin / Staff Entry
          return MaterialPageRoute(
            builder: (context) => const RoleSelectScreen(),
            settings: settings,
          );
        },
      ),
    );
  }
}