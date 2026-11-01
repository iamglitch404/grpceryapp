import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';

/// Bottom navigation footer displaying Home, Categories, Deals, Cart (with live badge), and Account.
class BottomNavigation extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Color? backgroundColor;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartStateProvider);
    final cartCount = cartState.cartItems.length;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF8F9FA),
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.grid_view_rounded, 'Categories'),
              _buildNavItem(2, Icons.favorite_border_rounded, 'Favorites'),
              _buildNavItem(
                3,
                Icons.shopping_cart_outlined,
                'Cart',
                badgeCount: cartCount > 0 ? cartCount : null,
              ),
              _buildNavItem(4, Icons.person_outline, 'Account'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int? badgeCount}) {
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF185B3A) : const Color(0xFF64748B);

    Widget iconWidget = Icon(
      icon,
      color: color,
      size: 24,
    );

    if (badgeCount != null && badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF185B3A),
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Retain backward-compatible aliases
typedef CustomerBottomNavigation = BottomNavigation;
typedef CustomFooter = BottomNavigation;
