import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'utils/platform_check.dart';
import 'services/auth_provider.dart';
import 'services/invoice_provider.dart';
import 'services/backup_service.dart';
import 'services/daily_scheduler.dart';
import 'services/report_settings_service.dart';
import 'services/server_config.dart';
import 'services/api_service.dart';
import 'services/local_order_storage.dart';

import 'providers/product_provider.dart';
import 'providers/category_provider.dart';
import 'providers/order_provider.dart';
import 'providers/kitchen_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/expense_provider.dart';

import 'screens/role_select_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/kitchen_kds_screen.dart';
import 'screens/server_table_screen.dart';
import 'screens/customer_order_screen.dart';
import 'widgets/idle_logout_wrapper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. SERVER CONFIG INIT
    await ServerConfig.loadIp();
    debugPrint('✅ Server Config loaded: ${ServerConfig.baseUrl}');

    // 2. HIVE INIT
    await Hive.initFlutter();
    
    // 3. OPEN HIVE BOXES (CRITICAL FOR AUTH & SETTINGS)
    await Hive.openBox('auth');
    await ReportSettingsService.init();
    await LocalOrderStorage.init(); // Fixed missing orders box init
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => InvoiceProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => BillingProvider()),
          ChangeNotifierProvider(
            create: (_) {
              final kp = KitchenProvider();
              kp.autoSetSessionByTime();
              return kp;
            },
          ),
          ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ],
        child: const RestaurantApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('🔴 ZONED ERROR: $error');
  });
}

class RestaurantApp extends StatelessWidget {
  const RestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Restaurant Billing',
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFFFF6A00),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              elevation: 0,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const IdleLogoutWrapper(
            child: RootRouter(),
          ),
          // ── Web URL routing: /menu/T1 opens customer order page ──
          onGenerateRoute: (settings) {
            final uri = Uri.tryParse(settings.name ?? '');
            if (uri != null && uri.pathSegments.length == 2 &&
                uri.pathSegments[0] == 'menu') {
              final tableNo = uri.pathSegments[1];
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => CustomerOrderScreen(tableNo: tableNo),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      // 🚀 Trigger initial data load from server
      await Future.wait([
        context.read<ProductProvider>().loadProducts(),
        context.read<CategoryProvider>().loadCategories(),
        context.read<OrderProvider>().loadAllActiveOrders(),
      ]);
    } catch (e) {
      debugPrint('🔴 INIT ERROR: $e');
    }
    
    if (mounted) setState(() => _initialized = true);
  }

  Widget _buildAuthRouter() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn || auth.role == null) {
          return const RoleSelectScreen();
        }
        if (auth.isAdmin) return const AdminDashboardScreen();
        if (auth.isStaff) return BillingScreen(onToggleTheme: () {});
        if (auth.isServer) return const ServerTableScreen();
        if (auth.isKitchen) return const KitchenKDSScreen();
        return const RoleSelectScreen();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A00))),
      );
    }

    // Zero Configuration: Go straight to Auth
    return _buildAuthRouter();
  }
}