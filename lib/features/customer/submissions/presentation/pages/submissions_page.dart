import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/submissions/data/repositories/submission_repository.dart';
import 'package:app/features/customer/submissions/presentation/pages/submit_product_page.dart';
import 'package:app/core/widgets/product_qr_sheet.dart';

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  final SubmissionRepository _repo = CubePod.get<SubmissionRepository>();

  List<Map<String, dynamic>> _products = [];

  String _searchQuery = '';
  String _selectedStatusTab = 'All'; // 'All', 'listed', 'pending', 'scheduled_for_pickup', 'rejected'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authRepo = CubePod.get<AuthRepository>();

    try {
      final user = authRepo.currentUser;
      final isAdmin = user?['role'] == 'admin';

      // If admin, fetch all products; if seller/user, fetch user's submissions
      final prods = isAdmin
          ? await _repo.fetchProducts(authRepo.authHeaders)
          : await _repo.fetchMySubmissions(authRepo.authHeaders);

      if (mounted) {
        setState(() {
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SubmissionsPage] load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleProductStock(Map<String, dynamic> product) async {
    final authRepo = CubePod.get<AuthRepository>();
    final id = product['id']?.toString() ?? '';
    final currentActive = product['is_active'] ?? true;
    final nextActive = !currentActive;

    setState(() {
      product['is_active'] = nextActive;
    });

    final success = await _repo.updateProduct(authRepo.authHeaders, id, {
      'is_active': nextActive,
    });

    if (!success && mounted) {
      setState(() {
        product['is_active'] = currentActive;
      });
      _showToast('Failed to update status', isError: true);
    } else {
      _showToast(nextActive ? 'Product is now active in store' : 'Product marked inactive');
    }
  }

  Future<void> _handleAdminApproval(Map<String, dynamic> product, String action) async {
    final authRepo = CubePod.get<AuthRepository>();
    final id = product['id']?.toString() ?? '';

    String? rejectionReason;
    String? pickupTime;

    if (action == 'reject') {
      final reasonController = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Reject Submission', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Specify the reason for rejection to notify the seller:', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Incomplete packaging details or quality mismatch',
                  hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B)))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
              child: Text('Reject', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      rejectionReason = reasonController.text.trim();
    } else if (action == 'schedule_pickup') {
      pickupTime = product['pickup_time'] ?? 'Tomorrow 10:00 AM';
    }

    final success = await _repo.processApprovalAction(
      authRepo.authHeaders,
      productId: id,
      action: action,
      pickupTime: pickupTime,
      rejectionReason: rejectionReason,
    );

    if (success) {
      _showToast(action == 'list_in_store' ? 'Product is now LIVE in store category!' : 'Status updated successfully');
      _loadData();
    } else {
      _showToast('Failed to update approval status', isError: true);
    }
  }

  Future<void> _deleteProduct(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Product?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove "$title"?',
          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authRepo = CubePod.get<AuthRepository>();
      final success = await _repo.deleteProduct(authRepo.authHeaders, id);
      if (success) {
        setState(() {
          _products.removeWhere((p) => p['id']?.toString() == id);
        });
        _showToast('Product deleted');
      } else {
        _showToast('Failed to delete product', isError: true);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF185B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final code = (p['product_code'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase()) || code.contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final status = p['approval_status']?.toString() ?? (p['is_active'] == true ? 'listed' : 'pending');

      if (_selectedStatusTab == 'All') return true;
      return status.toLowerCase() == _selectedStatusTab.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final totalCount = _products.length;
    final liveCount = _products.where((p) => (p['approval_status'] == 'listed' || (p['approval_status'] == null && p['is_active'] == true))).length;
    final pendingCount = _products.where((p) => p['approval_status'] == 'pending').length;
    final scheduledCount = _products.where((p) => p['approval_status'] == 'scheduled_for_pickup').length;

    final user = CubePod.get<AuthRepository>().currentUser;
    final isAdmin = user?['role'] == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF9),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isAdmin ? 'Product & Listing Control' : 'My Product Submissions',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: InkWell(
                onTap: () async {
                  final added = await Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (_) => const SubmitProductPage()),
                  );
                  if (added == true) _loadData();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: Color(0xFF185B3A)),
                      const SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: const Color(0xFF185B3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF185B3A),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── 1. Top Stat Counters Bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Total Items', '$totalCount', const Color(0xFF0F172A)),
                      Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
                      _buildSummaryItem('Live in Store', '$liveCount', const Color(0xFF15803D)),
                      Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
                      _buildSummaryItem('Pending Review', '$pendingCount', const Color(0xFFB45309)),
                      Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
                      _buildSummaryItem('Pickup Ready', '$scheduledCount', const Color(0xFF0369A1)),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Search & Status Tabs ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: GoogleFonts.outfit(fontSize: 14.5, color: const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'Search by item name or Product ID...',
                                hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () => setState(() => _searchQuery = ''),
                              child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status Filter Tabs
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildStatusTab('All', 'All ($totalCount)'),
                        _buildStatusTab('listed', '🟢 Live Store ($liveCount)'),
                        _buildStatusTab('pending', '🟡 Pending ($pendingCount)'),
                        _buildStatusTab('scheduled_for_pickup', '🚚 Pickup Ready ($scheduledCount)'),
                        _buildStatusTab('rejected', '🔴 Rejected'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── 3. Product Cards List ──
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF185B3A))),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 40, color: Color(0xFF185B3A)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No products found in this tab',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload an item to generate a QR pass and schedule pickup',
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final added = await Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => const SubmitProductPage()),
                          );
                          if (added == true) _loadData();
                        },
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        label: Text('Upload Product', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = filtered[index];
                      return _buildProductCard(product, isAdmin);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const SubmitProductPage()),
          );
          if (added == true) _loadData();
        },
        backgroundColor: const Color(0xFF185B3A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Upload Item',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTab(String statusKey, String label) {
    final isSelected = _selectedStatusTab.toLowerCase() == statusKey.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedStatusTab = statusKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF185B3A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isAdmin) {
    final id = product['id']?.toString() ?? '';
    final title = product['title']?.toString() ?? 'Product';
    final unit = product['unit']?.toString() ?? '1 unit';
    final imageUrl = product['image_url']?.toString();
    final code = product['product_code']?.toString() ?? 'AERO-PRD-${id.substring(0, 6).toUpperCase()}';
    final status = product['approval_status']?.toString() ?? (product['is_active'] == true ? 'listed' : 'pending');
    final pickupAddress = product['pickup_address']?.toString() ?? 'Default Store';
    final isActive = product['is_active'] ?? (status == 'listed');

    final pricePaise = product['price_paise'] is int
        ? product['price_paise'] as int
        : int.tryParse(product['price_paise']?.toString() ?? '0') ?? 0;
    final priceRs = (pricePaise / 100).toStringAsFixed(pricePaise % 100 == 0 ? 0 : 2);

    Color statusColor;
    Color statusBgColor;
    String statusBadgeText;

    switch (status) {
      case 'listed':
        statusColor = const Color(0xFF15803D);
        statusBgColor = const Color(0xFFDCFCE7);
        statusBadgeText = 'Live in Category';
        break;
      case 'scheduled_for_pickup':
        statusColor = const Color(0xFF0369A1);
        statusBgColor = const Color(0xFFE0F2FE);
        statusBadgeText = 'Pickup Scheduled';
        break;
      case 'rejected':
        statusColor = const Color(0xFFB91C1C);
        statusBgColor = const Color(0xFFFEE2E2);
        statusBadgeText = 'Rejected';
        break;
      case 'pending':
      default:
        statusColor = const Color(0xFFB45309);
        statusBgColor = const Color(0xFFFEF3C7);
        statusBadgeText = 'Pending Approval';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
          // Header row with Product Code & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      code,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusBadgeText,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Info Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 76,
                  height: 76,
                  color: const Color(0xFFF8FAFC),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.shopping_basket_outlined,
                            size: 32,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      : const Icon(Icons.shopping_basket_outlined, size: 32, color: Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹$priceRs • $unit',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF185B3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            pickupAddress,
                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (product['id'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'ID: ${product['id']}',
                          style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Bottom Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // View QR Pass Button
              InkWell(
                onTap: () => ProductQrSheet.show(context, product),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFF185B3A)),
                      const SizedBox(width: 5),
                      Text(
                        'View QR Pass',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF185B3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Admin or Edit Action Buttons
              Row(
                children: [
                  if (isAdmin) ...[
                    if (status == 'pending') ...[
                      InkWell(
                        onTap: () => _handleAdminApproval(product, 'schedule_pickup'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Schedule Pickup',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0369A1)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (status == 'scheduled_for_pickup') ...[
                      InkWell(
                        onTap: () => _handleAdminApproval(product, 'list_in_store'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Confirm & List Live',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (status != 'rejected' && status != 'listed') ...[
                      InkWell(
                        onTap: () => _handleAdminApproval(product, 'reject'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Reject',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],

                  if (status == 'listed')
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: const Color(0xFF185B3A),
                        onChanged: (_) => _toggleProductStock(product),
                      ),
                    ),

                  // Edit
                  InkWell(
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => SubmitProductPage(initialProduct: product),
                        ),
                      );
                      if (updated == true) _loadData();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Delete
                  InkWell(
                    onTap: () => _deleteProduct(id, title),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef ProductManagementPage = SubmissionsPage;
