import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/widgets/skeletonImage.dart';

class AdminProductItemCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onQuickToggleActive;
  final Function(int newStock) onStockUpdate;
  final VoidCallback onStockPrompt;

  const AdminProductItemCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onQuickToggleActive,
    required this.onStockUpdate,
    required this.onStockPrompt,
  });

  Widget _buildStepperBtn({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 14, color: onTap != null ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = product['title'] ?? 'Product';
    final image = product['image_url'] ?? '';
    final unit = product['unit'] ?? '1 kg';
    final pricePaise = product['price_paise'] as int? ?? 0;
    final origPricePaise = product['original_price_paise'] as int? ?? 0;
    final priceVal = (pricePaise / 100).round();
    final origVal = (origPricePaise / 100).round();
    final stock = product['stock_quantity'] as int? ?? 0;
    final isActive = product['is_active'] != false;
    final catName = product['category_name']?.toString() ?? '';
    final subName = product['subcategory_name']?.toString() ?? '';

    int? discountPercent;
    if (origVal > priceVal && origVal > 0) {
      discountPercent = (((origVal - priceVal) / origVal) * 100).round();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              // Card Top Header: Category/Subcategory & Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                child: Row(
                  children: [
                    // Category & Subcategory Badge
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              catName.isNotEmpty ? catName : 'General',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF185B3A),
                              ),
                            ),
                          ),
                          if (subName.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text('›', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                subName,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Horizontal Action Bar: Active Toggle + Chevron Indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: onQuickToggleActive,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? 'Active' : 'Hidden',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Card Body: Image + Product Info + Stock
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                                if (!isActive)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.40),
                                    child: Center(
                                      child: Text(
                                        'Inactive',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '₹$priceVal',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF185B3A),
                                    ),
                                  ),
                                  if (origVal > priceVal) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '₹$origVal',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                  if (discountPercent != null && discountPercent > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$discountPercent% OFF',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  Text('• $unit', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  if (product['is_special_deal'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Deal', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                                    ),
                                  if (product['is_todays_choice'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text("Today's Choice", style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA))),
                                    ),
                                  if (product['is_popular'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Popular', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFBE185D))),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Stock Row
                    Row(
                      children: [
                        Text(
                          'Stock',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _buildStepperBtn(
                          icon: Icons.remove,
                          onTap: stock > 0 ? () => onStockUpdate((stock - 1).clamp(0, 99999)) : null,
                        ),
                        GestureDetector(
                          onTap: onStockPrompt,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$stock',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        _buildStepperBtn(
                          icon: Icons.add,
                          onTap: () => onStockUpdate(stock + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

