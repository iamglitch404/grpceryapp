import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/di/injection.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/features/admin/products/providers/adminProductProviders.dart';
import 'package:app/features/admin/products/widgets/productRequestCard.dart';

class ProductReviewPage extends ConsumerWidget {
  const ProductReviewPage({super.key});

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> product,
    required String action,
    String? rejectionReason,
  }) async {
    final authRepo = ref.read(authRepositoryProvider);
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

      if (context.mounted) Navigator.pop(context); // pop loading dialog

      if (res.statusCode == 200) {
        if (context.mounted) {
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
        ref.invalidate(adminProductSubmissionsFutureProvider);
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'Action failed';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint('[ProductReviewPage] action error: $e');
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> product) {
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
                context,
                ref,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(adminProductReviewTabProvider);
    final searchQuery = ref.watch(adminProductSearchQueryProvider);
    final submissionsAsync = ref.watch(adminProductSubmissionsFutureProvider);

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
            onPressed: () => ref.invalidate(adminProductSubmissionsFutureProvider),
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
                  onChanged: (val) => ref.read(adminProductSearchQueryProvider.notifier).state = val,
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
                      _buildFilterChip(ref, selectedTab, 'pending', 'Pending Requests', Icons.pending_actions_rounded, const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _buildFilterChip(ref, selectedTab, 'listed', 'Approved & Live', Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      _buildFilterChip(ref, selectedTab, 'rejected', 'Rejected', Icons.cancel_outlined, const Color(0xFFE11D48)),
                      const SizedBox(width: 8),
                      _buildFilterChip(ref, selectedTab, 'all', 'All Submissions', Icons.list_alt_rounded, const Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Submissions List
          Expanded(
            child: submissionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A))),
              error: (err, _) => Center(child: Text('Error loading submissions: $err')),
              data: (submissions) {
                final filtered = submissions.where((p) {
                  if (searchQuery.isEmpty) return true;
                  final query = searchQuery.toLowerCase();
                  final title = (p['title'] ?? '').toString().toLowerCase();
                  final code = (p['product_code'] ?? '').toString().toLowerCase();
                  final sellerName = ((p['users'] ?? p['accounts'])?['name'] ?? '').toString().toLowerCase();
                  final location = (p['pickup_address'] ?? p['seller_location'] ?? '').toString().toLowerCase();
                  return title.contains(query) || code.contains(query) || sellerName.contains(query) || location.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
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
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF185B3A),
                  onRefresh: () => ref.refresh(adminProductSubmissionsFutureProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) => AdminProductRequestCard(
                      product: filtered[idx],
                      onReject: (p) => _showRejectDialog(context, ref, p),
                      onApproveAndList: (p) => _updateStatus(context, ref, product: p, action: 'list_in_store'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String selectedTab, String key, String label, IconData icon, Color activeColor) {
    return AdminProductFilterChip(
      tabKey: key,
      label: label,
      icon: icon,
      activeColor: activeColor,
      isSelected: selectedTab == key,
      onTap: () {
        ref.read(adminProductReviewTabProvider.notifier).state = key;
      },
    );
  }
}

// Retain alias for backward compatibility
typedef AdminProductReviewPage = ProductReviewPage;
