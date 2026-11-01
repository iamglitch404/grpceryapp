import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/admin/dashboard/providers/dashboardProviders.dart';
import 'package:app/features/admin/dashboard/widgets/leaderboardCustomerView.dart';
import 'package:app/features/admin/dashboard/widgets/leaderboardDeliverymanView.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
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
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  String get _selectedTab => ref.watch(adminLeaderboardSelectedTabProvider);
  bool get _isRefreshing => ref.watch(adminLeaderboardIsRefreshingProvider);

  Future<void> _handleRefresh() async {
    ref.read(adminLeaderboardIsRefreshingProvider.notifier).state = true;
    await widget.onRefresh();
    if (mounted) {
      ref.read(adminLeaderboardIsRefreshingProvider.notifier).state = false;
    }
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
        ref.read(adminLeaderboardSelectedTabProvider.notifier).state = key;
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
              LeaderboardCustomerView(
                customers: widget.customerRankings,
                onRefresh: _handleRefresh,
              )
            else
              LeaderboardDeliverymanView(
                deliverymen: widget.deliverymanRankings,
                onRefresh: _handleRefresh,
              ),
          ],
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminLeaderboardPage = LeaderboardPage;
