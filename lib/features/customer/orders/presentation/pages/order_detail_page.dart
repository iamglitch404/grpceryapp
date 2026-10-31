import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

  String _formatCurrency(dynamic amount) {
    int val = 0;
    if (amount is int) {
      val = amount;
    } else if (amount is String) {
      val = int.tryParse(amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    String result = val.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return 'Rs $result';
  }

  @override
  Widget build(BuildContext context) {
    // Determine status color and description
    final status = (order['status'] ?? 'Pending').toString();
    final isCanceled = status.toLowerCase() == 'canceled' || status.toLowerCase() == 'cancelled';
    final isOnTheWay = status.toLowerCase() == 'on the way' || status.toLowerCase() == 'delivering';

    Color statusColor = const Color(0xFF185B3A);
    Color statusBgColor = const Color(0xFFE8F5E9);
    if (isCanceled) {
      statusColor = const Color(0xFFE57373);
      statusBgColor = const Color(0xFFFFEBEE);
    } else if (isOnTheWay) {
      statusColor = const Color(0xFFF7C35B);
      statusBgColor = const Color(0xFFFFFDE7);
    }

    final List<dynamic> items = order['order_items'] ?? [];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2D2D), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Order Detail',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            // Order overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (order['store'] ?? 'Dovan Express').toString(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (order['status'] ?? 'Pending').toString(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Order #${order['id']?.toString().substring(0, order['id'].toString().length > 8 ? 8 : order['id'].toString().length).toUpperCase() ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order['created_at'] != null ? order['created_at'].toString().substring(0, 10) : 'Recent',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tracker for "On the way"
            if (isOnTheWay) ...[
              const Text(
                'Delivery Tracker',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF185B3A), size: 20),
                        Expanded(child: Container(height: 2, color: const Color(0xFF185B3A))),
                        const Icon(Icons.local_shipping, color: Color(0xFF185B3A), size: 24),
                        Expanded(child: Container(height: 2, color: Colors.grey.shade300)),
                        Icon(Icons.home, color: Colors.grey.shade300, size: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Packed', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Out for Delivery', style: TextStyle(fontSize: 12, color: Color(0xFF185B3A), fontWeight: FontWeight.bold)),
                        Text('Arrived', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Dual Location Verification Card (User Origin + Delivery Address)
            const Text(
              'Location & Delivery Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFF185B3A), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery Destination',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (order['destination_address'] ?? order['address_snapshot']?['street'] ?? order['address_snapshot']?['address'] ?? 'Home Address').toString(),
                              style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (order['device_location_address'] != null) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.my_location_rounded, color: Color(0xFF64748B), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Placed From (Device Location)',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order['device_location_address'].toString(),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (order['delivery_slot'] != null || order['payment_method'] != null) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Delivery Slot', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              Text((order['delivery_slot'] ?? 'Standard').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Method', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              Text((order['payment_method'] ?? 'COD').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items List
            const Text(
              'Items Purchased',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No item details available',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  : Column(
                      children: items.map((item) {
                        final product = (item['products'] is Map ? item['products'] : {}) as Map;
                        final title = (item['title_snapshot'] ?? product['title'] ?? product['name'] ?? 'Item').toString();
                        final unit = (item['unit_snapshot'] ?? product['unit'] ?? '1 kg').toString();
                        final qty = item['quantity'] ?? 1;
                        final pricePaise = (item['price_paise_snapshot'] as num?)?.toInt();
                        final price = pricePaise != null ? pricePaise ~/ 100 : (item['price'] ?? 0);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$unit x $qty',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Text(
                                _formatCurrency(price),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),

            // Price Details
            const Text(
              'Price Summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price', style: TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  Text(
                    _formatCurrency(order['total_paise'] != null ? (order['total_paise'] as num).toInt() ~/ 100 : order['total_amount']),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF185B3A)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
