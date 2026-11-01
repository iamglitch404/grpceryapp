import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/widgets/notiSvgs.dart';

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String timeStr;
  final ValueChanged<Map<String, dynamic>> onDismissed;
  final ValueChanged<Map<String, dynamic>> onAction;
  final ValueChanged<Map<String, dynamic>> onMarkRead;

  const NotificationCard({
    super.key,
    required this.item,
    required this.timeStr,
    required this.onDismissed,
    required this.onAction,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Notification';
    final message = item['message']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'general';
    final iconId = item['icon_id']?.toString() ?? item['icon_type']?.toString();
    final isRead = item['is_read'] == true;
    final isGlobal = item['is_global'] == true || type == 'announcement';

    // Category Pill details
    String categoryPillText;
    Color categoryPillBg;
    Color categoryPillColor;

    if (isGlobal || type == 'announcement') {
      categoryPillText = 'GLOBAL ANNOUNCEMENT';
      categoryPillBg = const Color(0xFFF3E8FF);
      categoryPillColor = const Color(0xFF7C3AED);
    } else if (type == 'product_submission' || type == 'pickup_scheduled' || type == 'product_listed') {
      categoryPillText = 'SELLER & LOGISTICS';
      categoryPillBg = const Color(0xFFFFFBEB);
      categoryPillColor = const Color(0xFFB45309);
    } else if (type == 'order') {
      categoryPillText = 'ORDER UPDATE';
      categoryPillBg = const Color(0xFFE8F5EE);
      categoryPillColor = const Color(0xFF185B3A);
    } else if (type == 'promo') {
      categoryPillText = 'SPECIAL DEAL';
      categoryPillBg = const Color(0xFFFEF3C7);
      categoryPillColor = const Color(0xFFD97706);
    } else {
      categoryPillText = 'NOTICE';
      categoryPillBg = const Color(0xFFF1F5F9);
      categoryPillColor = const Color(0xFF64748B);
    }

    // Action button label & icon
    String? actionBtnText;
    IconData? actionBtnIcon;

    if (type.startsWith('product_') || type == 'pickup_scheduled') {
      actionBtnText = 'View QR & Pickup Pass';
      actionBtnIcon = Icons.qr_code_2_rounded;
    } else if (type == 'order') {
      actionBtnText = 'Track Order';
      actionBtnIcon = Icons.local_shipping_outlined;
    } else if (type == 'promo' || type == 'announcement') {
      actionBtnText = 'Explore Deals & Store';
      actionBtnIcon = Icons.arrow_forward_rounded;
    }

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? const Color(0xFFF1F5F9) : const Color(0xFFBBF7D0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon + Title/Category + Relative Time & Unread Dot
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NotiSvgs(iconId: iconId, type: type, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryPillBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryPillText,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: categoryPillColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF185B3A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Message Content
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),

            // Responsive Action Buttons Row
            if (actionBtnText != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => onAction(item),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185B3A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actionBtnIcon != null) ...[
                            Icon(actionBtnIcon, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            actionBtnText,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isRead)
                    InkWell(
                      onTap: () => onMarkRead(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Mark as read',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
