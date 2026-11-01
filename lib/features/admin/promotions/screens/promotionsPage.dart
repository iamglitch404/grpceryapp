import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';

import 'package:app/features/admin/promotions/providers/adminPromotionProviders.dart';

class PromotionsPage extends ConsumerStatefulWidget {
  const PromotionsPage({super.key});

  @override
  ConsumerState<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends ConsumerState<PromotionsPage> {
  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    ref.read(adminPromotionsLoadingProvider.notifier).state = true;
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/promotions'),
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        ref.read(adminPromotionsListProvider.notifier).state =
            (data is List) ? data : (data['promotions'] ?? []);
        ref.read(adminPromotionsLoadingProvider.notifier).state = false;
      }
    } catch (e) {
      if (mounted) ref.read(adminPromotionsLoadingProvider.notifier).state = false;
      debugPrint('Error fetching promotions: $e');
    }
  }

  Future<void> _deletePromotion(dynamic id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Promotion?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove this coupon code?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/promotions?id=$id'),
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      _fetchPromotions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promotion deleted successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting promo: $e');
    }
  }

  void _showPromotionDialog({Map<String, dynamic>? promo}) {
    final isEdit = promo != null;
    final codeCtrl = TextEditingController(text: isEdit ? (promo['code'] ?? '') : '');
    final titleCtrl = TextEditingController(text: isEdit ? (promo['title'] ?? '') : '');
    final descCtrl = TextEditingController(text: isEdit ? (promo['description'] ?? '') : '');
    final discountCtrl = TextEditingController(text: isEdit ? (promo['discount_value']?.toString() ?? promo['discount_percent']?.toString() ?? '20') : '20');
    final minSpendCtrl = TextEditingController(text: isEdit ? (promo['min_order_amount']?.toString() ?? '300') : '300');
    String discountType = isEdit ? (promo['discount_type'] ?? 'percentage') : 'percentage';

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Coupon Code' : 'Create New Coupon',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField('Coupon Code *', codeCtrl, 'e.g. MEGA50 or WELCOME20', isUpper: true),
                          const SizedBox(height: 14),
                          _buildField('Campaign Title *', titleCtrl, 'e.g. 20% Off Weekend Grocery Sale'),
                          const SizedBox(height: 14),
                          _buildField('Description', descCtrl, 'e.g. Valid on all fresh organic produce', maxLines: 2),
                          const SizedBox(height: 14),

                          // Discount Type Selector
                          Text('Discount Type', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Text('Percentage (%)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                  selected: discountType == 'percentage',
                                  selectedColor: const Color(0xFFDCFCE7),
                                  onSelected: (val) => setDialogState(() => discountType = 'percentage'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ChoiceChip(
                                  label: Text('Fixed Amount (₹)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                  selected: discountType == 'fixed',
                                  selectedColor: const Color(0xFFDCFCE7),
                                  onSelected: (val) => setDialogState(() => discountType = 'fixed'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(child: _buildField('Discount Value *', discountCtrl, '20', isNumber: true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildField('Min Order (₹)', minSpendCtrl, '300', isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF185B3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isSaving ? null : () async {
                                if (codeCtrl.text.trim().isEmpty || titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Coupon Code and Title are required')),
                                  );
                                  return;
                                }

                                setDialogState(() => isSaving = true);
                                try {
                                  final payload = {
                                    if (isEdit) 'id': promo['id'],
                                    'code': codeCtrl.text.trim().toUpperCase(),
                                    'title': titleCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'discount_type': discountType,
                                    'discount_value': double.tryParse(discountCtrl.text) ?? 20.0,
                                    'min_order_amount': double.tryParse(minSpendCtrl.text) ?? 0.0,
                                    'is_active': true,
                                  };

                                  final res = isEdit
                                      ? await http.put(
                                          Uri.parse('${AppConfig.apiUrl}/admin/promotions'),
                                          headers: {
                                            ...ref.read(authRepositoryProvider).authHeaders,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode(payload),
                                        )
                                      : await http.post(
                                          Uri.parse('${AppConfig.apiUrl}/admin/promotions'),
                                          headers: {
                                            ...ref.read(authRepositoryProvider).authHeaders,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode(payload),
                                        );

                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    if (mounted && context.mounted) {
                                      Navigator.pop(context);
                                      _fetchPromotions();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(isEdit ? 'Coupon updated!' : 'Coupon created!')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error saving promo: $e');
                                } finally {
                                  setDialogState(() => isSaving = false);
                                }
                              },
                              child: isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      isEdit ? 'Save Coupon' : 'Create Voucher',
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {bool isNumber = false, bool isUpper = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          textCapitalization: isUpper ? TextCapitalization.characters : TextCapitalization.none,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.outfit(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(adminPromotionsLoadingProvider);
    final promotions = ref.watch(adminPromotionsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Promotions',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF185B3A),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('New Coupon', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showPromotionDialog(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
          : promotions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 54, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text('No promo codes active', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF185B3A),
                  onRefresh: _fetchPromotions,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 90),
                    itemCount: promotions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final promo = promotions[index];
                      final code = promo['code'] ?? 'CODE';
                      final title = promo['title'] ?? '';
                      final desc = promo['description'] ?? '';
                      final discount = promo['discount_value'] ?? promo['discount_percent'] ?? '20';
                      final isPct = (promo['discount_type'] ?? 'percentage') == 'percentage';
                      final minSpend = promo['min_order_amount'] ?? 0;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sell_rounded, color: Color(0xFF16A34A), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        code,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPct ? '$discount% OFF' : '₹$discount OFF',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(desc, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Min spend: ₹$minSpend',
                                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF475569)),
                                      onPressed: () => _showPromotionDialog(promo: promo),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFE11D48)),
                                      onPressed: () => _deletePromotion(promo['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Retain alias for backward compatibility
typedef ManagePromotionsPage = PromotionsPage;
