import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/widgets/skeleton_image.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';

class ProductReviewPage extends StatefulWidget {
  const ProductReviewPage({super.key});

  @override
  State<ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends State<ProductReviewPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _submissions = [];
  String _selectedTab = 'pending'; // 'all', 'pending', 'listed', 'rejected'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = CubePod.get<AuthRepository>();
      final uri = Uri.parse('${AppConfig.apiUrl}/admin/product-approvals?status=$_selectedTab');
      final res = await http.get(uri, headers: authRepo.authHeaders);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = (body['submissions'] ?? body['data'] ?? []) as List;
        setState(() {
          _submissions = list.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[ProductReviewPage] fetch error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus({
    required Map<String, dynamic> product,
    required String action,
    String? rejectionReason,
  }) async {
    final authRepo = CubePod.get<AuthRepository>();
    final productId = product['id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF185B3A)),
      ),
    );

    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/admin/product-approvals');
      final payload = {
        'product_id': productId,
        'action': action,
        'rejection_reason': ?rejectionReason,
      };

      final res = await http.patch(
        uri,
        headers: {
          ...authRepo.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (mounted) Navigator.pop(context); // pop loading dialog

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'list_in_store'
                    ? 'Product approved & listed in store!'
                    : 'Product submission rejected',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: action == 'list_in_store' ? const Color(0xFF185B3A) : const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        _fetchSubmissions();
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'Action failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('[ProductReviewPage] action error: $e');
    }
  }

  void _showRejectDialog(Map<String, dynamic> product) {
    final reasonCtrl = TextEditingController(text: 'Item does not meet marketplace standards');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Reject Product Request',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['title'] ?? 'Product',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Provide feedback to the seller...',
                labelStyle: GoogleFonts.outfit(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(
                product: product,
                action: 'reject',
                rejectionReason: reasonCtrl.text.trim(),
              );
            },
            child: Text('Reject Request', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _submissions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final title = (p['title'] ?? '').toString().toLowerCase();
      final code = (p['product_code'] ?? '').toString().toLowerCase();
      final sellerName = (p['users']?['name'] ?? '').toString().toLowerCase();
      final location = (p['pickup_address'] ?? p['seller_location'] ?? '').toString().toLowerCase();
      return title.contains(query) || code.contains(query) || sellerName.contains(query) || location.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Review & Approvals',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            Text(
              'User product submissions & location tracking',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF185B3A)),
            onPressed: _fetchSubmissions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                // Search Box
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: GoogleFonts.outfit(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by title, seller name, code or location...',
                    hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('pending', 'Pending Requests', Icons.pending_actions_rounded, const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _buildFilterChip('listed', 'Approved & Live', Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      _buildFilterChip('rejected', 'Rejected', Icons.cancel_outlined, const Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      _buildFilterChip('all', 'All Submissions', Icons.list_alt_rounded, const Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Submissions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No product requests found',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'User uploaded products for review will appear here.',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF185B3A),
                        onRefresh: _fetchSubmissions,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) => _buildProductRequestCard(filtered[idx]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon, Color activeColor) {
    final isSelected = _selectedTab == key;
    return InkWell(
      onTap: () {
        setState(() => _selectedTab = key);
        _fetchSubmissions();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRequestCard(Map<String, dynamic> p) {
    final title = p['title'] ?? 'Product';
    final image = p['image_url'] ?? '';
    final code = p['product_code'] ?? 'AERO-PRD-${p['id']?.toString().substring(0, 6).toUpperCase()}';
    final pricePaise = p['price_paise'] as int? ?? 0;
    final priceVal = (pricePaise / 100).round();
    final unit = p['unit'] ?? '1 kg';
    final stock = p['stock_quantity'] as int? ?? 10;
    final status = p['approval_status'] ?? 'pending';

    final seller = p['users'] as Map<String, dynamic>?;
    final sellerName = seller?['name'] ?? 'User / Seller';
    final sellerPhone = seller?['phone'] ?? p['pickup_phone'] ?? 'Not provided';
    final sellerId = p['seller_id'] ?? seller?['id'] ?? 'N/A';
    final location = p['pickup_address'] ?? p['seller_location'] ?? 'Location not specified';

    Color statusColor;
    String statusText;
    if (status == 'listed' || status == 'approved') {
      statusColor = const Color(0xFF16A34A);
      statusText = 'Approved & Live';
    } else if (status == 'rejected') {
      statusColor = const Color(0xFFE11D48);
      statusText = 'Rejected';
    } else {
      statusColor = const Color(0xFFD97706);
      statusText = 'Pending Approval';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code + Status Pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  code,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Product info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹$priceVal • $unit • Stock: $stock',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF185B3A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // SELLER & LOCATION BOX (Separate tracking container)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Seller details
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$sellerName (Phone: $sellerPhone)',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // User Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Location: $location',
                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF475569)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // User ID binding
                Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'User ID: $sellerId',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons (for pending items)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Reject Button
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFFECDD3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _showRejectDialog(p),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Approve & List Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text(
                      'Approve & List in Store',
                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _updateStatus(product: p, action: 'list_in_store'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminProductReviewPage = ProductReviewPage;
