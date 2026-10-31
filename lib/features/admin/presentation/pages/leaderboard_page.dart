import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/admin/presentation/pages/user_details_page.dart';
import 'package:app/features/admin/presentation/pages/users_page.dart';

class LeaderboardPage extends StatefulWidget {
  final List<Map<String, dynamic>> customerRankings;
  final List<Map<String, dynamic>> deliverymanRankings;
  final Future<void> Function() onRefresh;

  const LeaderboardPage({
    super.key,
    required this.customerRankings,
    required this.deliverymanRankings,
    required this.onRefresh,
  });

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String _selectedTab = 'customer'; // 'customer' or 'deliveryman'
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await widget.onRefresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Leaderboard & Records',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF185B3A)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 22),
            onPressed: _isRefreshing ? null : _handleRefresh,
            tooltip: 'Refresh Rankings',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFF185B3A),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Segmented Tab Selector (Full width, no overflow)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabBtn(
                      label: 'Customer Leaderboard',
                      key: 'customer',
                      icon: Icons.emoji_events_rounded,
                      badge: '${widget.customerRankings.length}',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTabBtn(
                      label: 'Deliveryman Records',
                      key: 'deliveryman',
                      icon: Icons.two_wheeler_rounded,
                      badge: '${widget.deliverymanRankings.length}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            if (_selectedTab == 'customer')
              _buildCustomerView()
            else
              _buildDeliverymanView(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBtn({
    required String label,
    required String key,
    required IconData icon,
    required String badge,
  }) {
    final isSelected = _selectedTab == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedTab = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF185B3A) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerView() {
    final customers = widget.customerRankings;
    if (customers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'No Customer Orders Yet',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              'Top customer rankings will appear here once orders are placed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: customers.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final c = entry.value;
        final userObj = c['user'] as Map<String, dynamic>;

        Color rankColor;
        Color rankBg;
        if (rank == 1) {
          rankColor = const Color(0xFFB45309);
          rankBg = const Color(0xFFFEF3C7);
        } else if (rank == 2) {
          rankColor = const Color(0xFF475569);
          rankBg = const Color(0xFFE2E8F0);
        } else if (rank == 3) {
          rankColor = const Color(0xFF9A3412);
          rankBg = const Color(0xFFFFEDD5);
        } else {
          rankColor = const Color(0xFF64748B);
          rankBg = const Color(0xFFF1F5F9);
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserDetailsPage(user: userObj)),
            ).then((_) => _handleRefresh());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Rank Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rankBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rankColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Customer Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        c['email'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Count & Points / Spent
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${c['order_count']} Orders',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${c['total_spent']}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDeliverymanView() {
    final deliverymen = widget.deliverymanRankings;
    if (deliverymen.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(Icons.two_wheeler_rounded, size: 44, color: Color(0xFFD97706)),
            const SizedBox(height: 12),
            Text(
              'No Delivery Personnel Found',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
            ),
            const SizedBox(height: 6),
            Text(
              'Assign any user to the Delivery Driver role in Manage Users to track their deliveries.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add_rounded, size: 16, color: Colors.white),
              label: Text('Manage Fleet in Users', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF185B3A),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UsersPage(initialFilter: 'Deliveryman')),
                ).then((_) => _handleRefresh());
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: deliverymen.map((d) {
        final userObj = d['user'] as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserDetailsPage(user: userObj)),
            ).then((_) => _handleRefresh());
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFFD97706)),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              d['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                                const SizedBox(width: 3),
                                Text('On Duty', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        d['phone'].isNotEmpty ? d['phone'] : d['email'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${d['completed_deliveries']} Delivered',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFFB45309)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d['active_deliveries']} Active runs',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF78350F), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminLeaderboardPage = LeaderboardPage;
