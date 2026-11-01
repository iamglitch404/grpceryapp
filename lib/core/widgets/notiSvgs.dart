import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Database-backed SVG / Vector Icon Selector for Notifications & Announcements
/// Maps `icon_id` / `icon_type` stored in PostgreSQL to rich curated SVG and vector badges.
class NotiSvgs extends StatelessWidget {
  final String? iconId;
  final String type;
  final double size;

  const NotiSvgs({
    super.key,
    this.iconId,
    required this.type,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final key = (iconId ?? type).toLowerCase().trim();

    Widget iconWidget;
    Color iconColor;
    Color bgColor;
    Color borderColor;

    switch (key) {
      // ── Announcements & Broadcasts ──
      case 'broadcast':
      case 'announcement':
        iconColor = const Color(0xFF7C3AED); // Royal Purple
        bgColor = const Color(0xFFF5F3FF);
        borderColor = const Color(0xFFDDD6FE);
        iconWidget = Icon(Icons.campaign_rounded, color: iconColor, size: size);
        break;
      case 'festival':
      case 'celebration':
        iconColor = const Color(0xFFEA580C); // Vibrant Orange
        bgColor = const Color(0xFFFFF7ED);
        borderColor = const Color(0xFFFFEDD5);
        iconWidget = Icon(Icons.celebration_rounded, color: iconColor, size: size);
        break;
      case 'feature':
      case 'new_feature':
        iconColor = const Color(0xFF0284C7); // Sky Blue
        bgColor = const Color(0xFFF0F9FF);
        borderColor = const Color(0xFFBAE6FD);
        iconWidget = Icon(Icons.auto_awesome_rounded, color: iconColor, size: size);
        break;

      // ── Product Submissions & QR Logistics ──
      case 'qr_pass':
      case 'qr_pickup':
      case 'product_submission':
      case 'product_submit':
        iconColor = const Color(0xFFB45309); // Amber Gold
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        iconWidget = Icon(Icons.qr_code_2_rounded, color: iconColor, size: size);
        break;
      case 'truck':
      case 'delivery':
      case 'pickup_scheduled':
        iconColor = const Color(0xFF0369A1); // Deep Ocean Blue
        bgColor = const Color(0xFFF0F9FF);
        borderColor = const Color(0xFFBAE6FD);
        iconWidget = Icon(Icons.local_shipping_rounded, color: iconColor, size: size);
        break;
      case 'store_live':
      case 'product_listed':
      case 'approved':
        iconColor = const Color(0xFF15803D); // Emerald Green
        bgColor = const Color(0xFFF0FDF4);
        borderColor = const Color(0xFFBBF7D0);
        iconWidget = Icon(Icons.storefront_rounded, color: iconColor, size: size);
        break;
      case 'rejected':
      case 'product_rejected':
        iconColor = const Color(0xFFB91C1C); // Crimson Red
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        iconWidget = Icon(Icons.cancel_outlined, color: iconColor, size: size);
        break;

      // ── Orders & Commerce ──
      case 'order':
      case 'order_placed':
      case 'bag':
        iconColor = const Color(0xFF185B3A); // Brand Forest Green
        bgColor = const Color(0xFFE8F5EE);
        borderColor = const Color(0xFFC7E6D7);
        iconWidget = Icon(Icons.shopping_bag_outlined, color: iconColor, size: size);
        break;

      // ── Deals & Discounts ──
      case 'deal':
      case 'mega_deal':
      case 'discount':
      case 'promo':
      case 'coupon':
        iconColor = const Color(0xFFD97706); // Gold Amber
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        iconWidget = Icon(Icons.local_offer_rounded, color: iconColor, size: size);
        break;

      // ── Rewards & Gamification ──
      case 'points':
      case 'reward':
      case 'stars':
        iconColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFFDE68A);
        iconWidget = Icon(Icons.stars_rounded, color: iconColor, size: size);
        break;

      // ── App SVG Bell Notification ──
      default:
        iconColor = const Color(0xFF185B3A);
        bgColor = const Color(0xFFE8F5EE);
        borderColor = const Color(0xFFC7E6D7);
        iconWidget = SvgPicture.asset(
          'assets/icons/ic_bell.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
        break;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: iconWidget),
    );
  }
}
