import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/features/admin/presentation/pages/dashboard_page.dart';
import 'package:app/features/admin/presentation/pages/products_page.dart';
import 'package:app/features/admin/presentation/pages/orders_page.dart';
import 'package:app/features/admin/presentation/pages/home_deals_page.dart';
import 'package:app/features/admin/presentation/pages/users_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const ProductsPage(),
    const OrdersPage(),
    const HomeDealsPage(),
    const UsersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
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
                _buildNavItem(0, Icons.dashboard_rounded),
                _buildNavItem(1, Icons.inventory_2_rounded),
                _buildNavItem(2, Icons.local_shipping_rounded),
                _buildNavItem(3, Icons.campaign_rounded),
                _buildNavItem(4, Icons.group_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    const activeColor = Color(0xFF185B3A);
    const inactiveColor = Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
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
