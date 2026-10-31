import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/services/cache_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/customer/presentation/pages/main_page.dart' as customer;
import 'package:app/features/admin/presentation/pages/main_page.dart' as admin;
import 'package:app/features/delivery/presentation/pages/delivery_dashboard_page.dart' as delivery;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  await CacheService.init();
  setupDependencies();
  await CubePod.get<AuthRepository>().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dovan',
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      theme: ThemeData(
        primaryColor: const Color(0xFF3BA772),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadePageTransitionsBuilder(),
            TargetPlatform.iOS: FadePageTransitionsBuilder(),
          },
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    _prewarmStats();
  }

  void _prewarmStats() {
    try {
      final authRepo = CubePod.get<AuthRepository>();
      if (authRepo.isLoggedIn) {
        authRepo.syncCurrentUser();
        CubePod.get<UserRepository>().fetchStats(authRepo.authHeaders);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: CubePod.get<AuthRepository>().authStateNotifier,
      builder: (context, user, _) {
        final role = (user?['role'] ?? 'customer').toString().toLowerCase();

        if (role == 'admin') {
          return const admin.MainPage();
        }

        if (role == 'delivery_man' || role.contains('delivery')) {
          return const delivery.DeliveryDashboardPage();
        }

        return const customer.MainPage();
      },
    );
  }
}


