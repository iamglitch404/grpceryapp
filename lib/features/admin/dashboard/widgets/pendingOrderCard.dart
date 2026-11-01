import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminPendingOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(String orderId, String newStatus) onUpdateStatus;

  const AdminPendingOrderCard({
    super.key,
    required this.order,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final id = (order['id'] ?? '').toString();
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final customerName = (order['customer_name'] ?? order['customer']?['name'] ?? 'Customer').toString();
    final phone = (order['customer_phone'] ?? order['phone'] ?? '').toString();
    final total = order['total_amount'] ?? order['total'] ?? '0';
    final paymentMethod = (order['payment_method'] ?? 'COD').toString();

    List<dynamic> items = [];
    if (order['order_items'] is List) {
      items = order['order_items'];
    } else if (order['items'] is List) {
      items = order['items'];
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber accent border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Order ID & Pending Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order #$shortId',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer Row
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                customerName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '•  $phone',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Total & Payment
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₹$total',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF185B3A),
                ),
              ),
              Text(
                paymentMethod,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Items preview
          if (items.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: items.take(3).map((item) {
                final itemTitle = item['title'] ?? item['name'] ?? item['product_title'] ?? 'Product';
                final qty = item['quantity'] ?? item['qty'] ?? 1;
                return Text(
                  '$itemTitle × $qty',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF475569),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: Mark Packed & Cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFFDA4AF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => onUpdateStatus(id, 'Cancelled'),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Mark Packed',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => onUpdateStatus(id, 'Packed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

