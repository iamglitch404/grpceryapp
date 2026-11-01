import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/customer/widgets/bottomNavigation.dart';
import 'package:app/features/customer/home/screens/homePage.dart';
import 'package:app/features/customer/explore/screens/explorePage.dart';
import 'package:app/features/customer/favorites/screens/favoritesPage.dart';
import 'package:app/features/customer/cart/screens/cartPage.dart';
import 'package:app/features/customer/profile/screens/profilePage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/favorites/providers/favoritesState.dart';
import 'package:app/features/customer/notifications/providers/notificationState.dart';

final customerMainTabIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

class MainPage extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainPage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
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
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(customerMainTabIndexProvider.notifier).state = widget.initialIndex;
        }
      });
    }
    ref.read(cartStateProvider).fetchCartItems();
    ref.read(favoritesStateProvider).fetchFavorites();
    ref.read(notificationStateProvider).fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(customerMainTabIndexProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(customerMainTabIndexProvider.notifier).state = index;
          if (index == 2) {
            ref.read(favoritesStateProvider).fetchFavorites();
          } else if (index == 3) {
            ref.read(cartStateProvider).fetchCartItems();
          }
        },
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef CustomerMainPage = MainPage;
