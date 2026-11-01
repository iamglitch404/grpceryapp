import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/admin/dashboard/providers/dashboardProviders.dart';
import 'package:app/features/admin/dashboard/screens/dashboardPage.dart';
import 'package:app/features/admin/products/screens/productsPage.dart';
import 'package:app/features/admin/orders/screens/ordersPage.dart';
import 'package:app/features/admin/promotions/screens/homeDealsPage.dart';
import 'package:app/features/admin/users/screens/usersPage.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  static const List<Widget> _pages = [
    DashboardPage(),
    ProductsPage(),
    OrdersPage(),
    HomeDealsPage(),
    UsersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(adminMainTabIndexProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(currentIndex, 0, Icons.dashboard_rounded),
                _buildNavItem(currentIndex, 1, Icons.inventory_2_rounded),
                _buildNavItem(currentIndex, 2, Icons.local_shipping_rounded),
                _buildNavItem(currentIndex, 3, Icons.campaign_rounded),
                _buildNavItem(currentIndex, 4, Icons.group_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int currentIndex, int index, IconData icon) {
    final isSelected = currentIndex == index;
    const activeColor = Color(0xFF185B3A);
    const inactiveColor = Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(adminMainTabIndexProvider.notifier).state = index;
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Icon(
          icon,
          size: 24,
          color: isSelected ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminMainPage = MainPage;
