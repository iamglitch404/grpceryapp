import 'package:flutter/material.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/customer/presentation/widgets/bottom_navigation.dart';
import 'package:app/features/customer/home/presentation/pages/home_page.dart';
import 'package:app/features/customer/explore/presentation/pages/explore_page.dart';
import 'package:app/features/customer/favorites/presentation/pages/favorites_page.dart';
import 'package:app/features/customer/cart/presentation/pages/cart_page.dart';
import 'package:app/features/customer/profile/presentation/pages/profile_page.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';

class MainPage extends StatefulWidget {
  final int initialIndex;

  const MainPage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomePage(),
    ExplorePage(),
    FavoritesPage(),
    CartPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    CubePod.get<CartState>().fetchCartItems();
    CubePod.get<NotificationState>().fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef CustomerMainPage = MainPage;
