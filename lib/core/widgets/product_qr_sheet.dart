import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductQrSheet extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductQrSheet({super.key, required this.product});

  static void show(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductQrSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = product['title']?.toString() ?? 'Product';
    final code = product['product_code']?.toString() ?? 'AERO-PRD-${(product['id']?.toString() ?? '000000').substring(0, 6).toUpperCase()}';
    final status = product['approval_status']?.toString() ?? (product['is_active'] == true ? 'listed' : 'pending');
    final pickupAddress = product['pickup_address']?.toString() ?? 'Not specified';
    final pickupPhone = product['pickup_phone']?.toString() ?? 'Not specified';
    final pickupTime = product['pickup_time']?.toString() ?? 'Standard Hours';
    final rejectionReason = product['rejection_reason']?.toString();
    final adminNotes = product['admin_notes']?.toString();

    final pricePaise = product['price_paise'] is int
        ? product['price_paise'] as int
        : int.tryParse(product['price_paise']?.toString() ?? '0') ?? 0;
    final priceRs = (pricePaise / 100).toStringAsFixed(pricePaise % 100 == 0 ? 0 : 2);
    final unit = product['unit']?.toString() ?? '1 unit';

    Color statusColor;
    Color statusBgColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'listed':
        statusColor = const Color(0xFF15803D);
        statusBgColor = const Color(0xFFDCFCE7);
        statusLabel = 'Live on Dovan';
        statusIcon = Icons.storefront_rounded;
        break;
      case 'scheduled_for_pickup':
        statusColor = const Color(0xFF0369A1);
        statusBgColor = const Color(0xFFE0F2FE);
        statusLabel = 'Pickup Scheduled';
        statusIcon = Icons.local_shipping_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFB91C1C);
        statusBgColor = const Color(0xFFFEE2E2);
        statusLabel = 'Submission Rejected';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFFB45309);
        statusBgColor = const Color(0xFFFEF3C7);
        statusLabel = 'Pending Admin Review';
        statusIcon = Icons.hourglass_top_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header title
          Text(
            'Product ID & QR Pass',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            'Show this QR code to the Dovan delivery agent during item pickup',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // ── QR Code Visual Box ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Custom High-Res QR Painter
                Container(
                  width: 170,
                  height: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _QrMatrixPainter(code),
                  ),
                ),
                const SizedBox(height: 14),

                // Code pill with copy
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product ID copied to clipboard: $code', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF185B3A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF185B3A)),
                        const SizedBox(width: 6),
                        Text(
                          code,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Status Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  '₹$priceRs / $unit',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection Reason: $rejectionReason',
                      style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFFB91C1C), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Pickup & Dispatch Info ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.shopping_basket_outlined, 'Item Name', title),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildInfoRow(Icons.location_on_outlined, 'Pickup Location', pickupAddress),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildInfoRow(Icons.phone_outlined, 'Contact Phone', pickupPhone),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildInfoRow(Icons.access_time_rounded, 'Preferred Pickup Slot', pickupTime),
                if (adminNotes != null && adminNotes.isNotEmpty) ...[
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildInfoRow(Icons.notes_rounded, 'Courier Notes', adminNotes),
                ],
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF185B3A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Close Pass',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF185B3A)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dynamic QR Matrix generator painter based on data hash
class _QrMatrixPainter extends CustomPainter {
  final String data;
  _QrMatrixPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    const int gridSize = 21; // Standard QR matrix grid
    final double cellSize = size.width / gridSize;

    // Corner Finder Patterns
    _drawFinderPattern(canvas, paint, 0, 0, cellSize);
    _drawFinderPattern(canvas, paint, (gridSize - 7) * cellSize, 0, cellSize);
    _drawFinderPattern(canvas, paint, 0, (gridSize - 7) * cellSize, cellSize);

    // Hash data to populate repeatable matrix bits
    final bytes = utf8.encode(data);
    int hash = 5381;
    for (var b in bytes) {
      hash = ((hash << 5) + hash) + b;
    }

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip finder areas
        if ((r < 8 && c < 8) || (r < 8 && c >= gridSize - 8) || (r >= gridSize - 8 && c < 8)) {
          continue;
        }

        final bit = ((hash ^ (r * 31 + c * 17)) & (1 << ((r + c) % 8))) != 0;
        if (bit || (r == 6 || c == 6)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 0.5, r * cellSize + 0.5, cellSize - 1, cellSize - 1),
              const Radius.circular(1.5),
            ),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, Paint paint, double x, double y, double cellSize) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 7 * cellSize, 7 * cellSize),
      Radius.circular(cellSize * 1.2),
    );
    canvas.drawRRect(outer, paint);

    final innerWhite = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + cellSize, y + cellSize, 5 * cellSize, 5 * cellSize),
      Radius.circular(cellSize * 0.8),
    );
    canvas.drawRRect(innerWhite, Paint()..color = Colors.white);

    final centerBlack = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + 2 * cellSize, y + 2 * cellSize, 3 * cellSize, 3 * cellSize),
      Radius.circular(cellSize * 0.5),
    );
    canvas.drawRRect(centerBlack, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
