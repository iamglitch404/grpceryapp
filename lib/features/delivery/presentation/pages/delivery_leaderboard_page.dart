import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

class DeliveryLeaderboardPage extends StatefulWidget {
  const DeliveryLeaderboardPage({super.key});

  @override
  State<DeliveryLeaderboardPage> createState() => _DeliveryLeaderboardPageState();
}

class _DeliveryLeaderboardPageState extends State<DeliveryLeaderboardPage> {
  bool _isLoading = true;
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final data = await CubePod.get<DeliveryRepository>().fetchLeaderboard();
    if (mounted) {
      setState(() {
        _leaderboard = data?['leaderboard'] ?? [];
        _myRank = data?['my_rank'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Rider Leaderboard',
          style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: const Color(0xFF185B3A),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF185B3A), Color(0xFF064E3B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF185B3A).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFCD34D), size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dovan Top Riders',
                                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rankings based on total successfully completed deliveries',
                                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Podium (Top 3)
                        if (_leaderboard.isNotEmpty) ...[
                          _buildPodium(),
                          const SizedBox(height: 28),
                        ],

                        // Full Rankings List
                        Text(
                          'All Delivery Partners',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _leaderboard.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final rider = _leaderboard[i];
                            final rank = rider['rank'] ?? (i + 1);
                            final count = rider['completed_deliveries_count'] ?? 0;
                            final name = rider['full_name'] ?? 'Rider';
                            final rating = rider['rating']?.toString() ?? '5.0';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  // Rank badge
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: rank == 1
                                          ? const Color(0xFFFEF3C7)
                                          : rank == 2
                                              ? const Color(0xFFF1F5F9)
                                              : rank == 3
                                                  ? const Color(0xFFFFEDD5)
                                                  : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#$rank',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: rank == 1
                                              ? const Color(0xFFD97706)
                                              : rank == 2
                                                  ? const Color(0xFF64748B)
                                                  : rank == 3
                                                      ? const Color(0xFFC2410C)
                                                      : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    child: Text(name[0].toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                            const SizedBox(width: 2),
                                            Text(rating, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                            const SizedBox(width: 8),
                                            Text(rider['vehicle_type']?.toString().toUpperCase() ?? 'BIKE', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Deliveries Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count Delivered',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Sticky Bottom Current Rider Rank Card
                  if (_myRank != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, -4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                '#${_myRank!['rank']}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Your Ranking: ${_myRank!['badge'] ?? 'Active Rider'}',
                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Keep delivering to climb up the leaderboard!',
                                    style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                '${_myRank!['completed_deliveries_count'] ?? 0} Done',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodium() {
    final first = _leaderboard.isNotEmpty ? _leaderboard[0] : null;
    final second = _leaderboard.length > 1 ? _leaderboard[1] : null;
    final third = _leaderboard.length > 2 ? _leaderboard[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place (Silver)
        if (second != null)
          Expanded(child: _buildPodiumColumn(second, 2, const Color(0xFF94A3B8), 130)),
        const SizedBox(width: 8),

        // 1st Place (Gold)
        if (first != null)
          Expanded(child: _buildPodiumColumn(first, 1, const Color(0xFFF59E0B), 160)),
        const SizedBox(width: 8),

        // 3rd Place (Bronze)
        if (third != null)
          Expanded(child: _buildPodiumColumn(third, 3, const Color(0xFFD97706), 110)),
      ],
    );
  }

  Widget _buildPodiumColumn(dynamic rider, int rank, Color crownColor, double height) {
    final name = rider['full_name'] ?? 'Rider';
    final count = rider['completed_deliveries_count'] ?? 0;

    return Column(
      children: [
        Icon(Icons.military_tech_rounded, color: crownColor, size: rank == 1 ? 30 : 24),
        const SizedBox(height: 4),
        CircleAvatar(
          radius: rank == 1 ? 26 : 22,
          backgroundColor: crownColor.withValues(alpha: 0.2),
          child: Text(
            name[0].toUpperCase(),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: rank == 1 ? 18 : 14, color: crownColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name.split(' ').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
        ),
        Text('$count dels', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [crownColor.withValues(alpha: 0.2), crownColor.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: crownColor.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: crownColor),
            ),
          ),
        ),
      ],
    );
  }
}
