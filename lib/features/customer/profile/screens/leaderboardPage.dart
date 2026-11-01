import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/profile/screens/allUsersPage.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF0284C7);
      case 'platinum':
        return const Color(0xFF7B2CBF);
      case 'gold':
        return const Color(0xFFD97706);
      case 'silver':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFB45309);
    }
  }

  Color _getAvatarBg(String name, int index) {
    final colors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF97316), // Orange
      const Color(0xFF1E3A8A), // Navy
      const Color(0xFFEF4444), // Coral Red
      const Color(0xFF10B981), // Emerald
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFEC4899), // Pink
    ];
    return colors[index % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _showUserProfileModal(Map<String, dynamic> user) {
    final rank = user['rank'] ?? 0;
    final name = user['name']?.toString() ?? 'Customer';
    final points = user['points']?.toString() ?? '0';
    final tier = user['tier']?.toString() ?? 'Diamond';
    final tierColor = _getTierColor(tier);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getAvatarBg(name, rank),
                    border: Border.all(color: tierColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: tierColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user['profile_image'] != null && user['profile_image'].toString().isNotEmpty
                        ? Image.network(
                            user['profile_image'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildInitialsText(name, 24),
                          )
                        : _buildInitialsText(name, 24),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$rank',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.diamond_outlined, size: 12, color: tierColor),
                  const SizedBox(width: 4),
                  Text(
                    '$tier Shopper',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: tierColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Global Rank',
                        style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#$rank',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                  Column(
                    children: [
                      Text(
                        'Total Points',
                        style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$points pts',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF2E8B57),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(customerLeaderboardFutureProvider);
    final data = leaderboardAsync.valueOrNull ?? const CustomerLeaderboardData();
    final topUsers = data.topUsers;
    final currentUserStats = data.currentUserStats;
    final podiumUsers = topUsers.take(3).toList();
    final remainingUsers = topUsers.skip(3).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildTopAppBar(context, topUsers),
      body: leaderboardAsync.isLoading && topUsers.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57)))
          : Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // ── Top 3 Podium Card Banner ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPodiumBanner(podiumUsers),
                      ),

                      const SizedBox(height: 20),

                      // ── Global Rankings Header ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF2E8B57), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Global Rankings',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            // Clickable View Users Action (Navigates to dedicated AllUsersPage)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => AllUsersPage(initialUsers: topUsers),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View Users',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2E8B57),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFF2E8B57)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Remaining Ranks List (All Top 50 directly scrollable) ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            for (int i = 0; i < remainingUsers.length; i++)
                              _buildRankCard(remainingUsers[i], i + 3),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100), // Spacing for sticky bottom bar
                    ],
                  ),
                ),

                // ── Sticky User Rank Bar ──
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildStickyUserRankBar(currentUserStats),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context, List<Map<String, dynamic>> topUsers) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF185B3A), size: 24),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Dovan Leaderboard',
            style: GoogleFonts.outfit(
              color: const Color(0xFF185B3A),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            'Shop more • Climb the ranks • Earn rewards',
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF185B3A), size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => AllUsersPage(initialUsers: topUsers),
                  ),
                );
              },
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumBanner(List<Map<String, dynamic>> podium) {
    final first = podium.isNotEmpty ? podium[0] : null;
    final second = podium.length > 1 ? podium[1] : null;
    final third = podium.length > 2 ? podium[2] : null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3E24), Color(0xFF135431), Color(0xFF1B6C41)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF135431).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Background Confetti & Sparkles
          Positioned(top: 25, left: 30, child: _buildConfettiDot(const Color(0xFFFFD700), 5)),
          Positioned(top: 45, left: 60, child: _buildConfettiDot(const Color(0xFFE2E8F0), 4)),
          Positioned(top: 30, right: 40, child: _buildConfettiDot(const Color(0xFFFFD700), 5)),
          Positioned(top: 55, right: 75, child: _buildConfettiDot(const Color(0xFFFED7AA), 4)),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              children: [
                // Top Center Glowing Trophy Badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E7E49),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4ADE80), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 20),
                  ),
                ),

                const SizedBox(height: 10),

                // 3 Podium Pillars Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── 2nd Place (Left) ──
                    if (second != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showUserProfileModal(second),
                          child: _buildPodiumColumn(
                            rank: 2,
                            user: second,
                            pillarBg: const Color(0xFFEBF1F6),
                            avatarBg: const Color(0xFF2563EB),
                            ringColor: const Color(0xFF93C5FD),
                            badgeBg: const Color(0xFF3B82F6),
                            tagLabel: '⚔️ Master',
                            tagBg: const Color(0xFFDCE6EF),
                            tagTextColor: const Color(0xFF334155),
                            height: 155,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // ── 1st Place (Center) ──
                    if (first != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showUserProfileModal(first),
                          child: _buildPodiumColumn(
                            rank: 1,
                            user: first,
                            pillarBg: const Color(0xFFFEF3C7),
                            avatarBg: const Color(0xFF0D9488),
                            ringColor: const Color(0xFFFFD700),
                            badgeBg: const Color(0xFFF59E0B),
                            tagLabel: '👑 Champion',
                            tagBg: const Color(0xFFFDE68A),
                            tagTextColor: const Color(0xFF92400E),
                            height: 190,
                            isFirst: true,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),

                    // ── 3rd Place (Right) ──
                    if (third != null)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showUserProfileModal(third),
                          child: _buildPodiumColumn(
                            rank: 3,
                            user: third,
                            pillarBg: const Color(0xFFFFEDE6),
                            avatarBg: const Color(0xFFEA580C),
                            ringColor: const Color(0xFFFDBA74),
                            badgeBg: const Color(0xFFF97316),
                            tagLabel: '🛡️ Elite',
                            tagBg: const Color(0xFFFED7AA),
                            tagTextColor: const Color(0xFF9A3412),
                            height: 140,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfettiDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildPodiumColumn({
    required int rank,
    required Map<String, dynamic> user,
    required Color pillarBg,
    required Color avatarBg,
    required Color ringColor,
    required Color badgeBg,
    required String tagLabel,
    required Color tagBg,
    required Color tagTextColor,
    required double height,
    bool isFirst = false,
  }) {
    final rawName = user['name']?.toString() ?? 'User';
    final points = user['points']?.toString() ?? '0';
    final avatarSize = isFirst ? 66.0 : 54.0;

    final nameParts = rawName.trim().split(RegExp(r'\s+'));
    final line1 = nameParts.take(nameParts.length > 2 ? 2 : 1).join(' ');
    final line2 = nameParts.length > 1 ? nameParts.skip(nameParts.length > 2 ? 2 : 1).join(' ') : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + Medal Badge
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarBg,
                border: Border.all(color: ringColor, width: isFirst ? 3.5 : 2.5),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.5),
                    blurRadius: isFirst ? 14 : 8,
                    spreadRadius: isFirst ? 2 : 0,
                  ),
                ],
              ),
              child: ClipOval(
                child: user['profile_image'] != null && user['profile_image'].toString().isNotEmpty
                    ? Image.network(
                        user['profile_image'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildInitialsText(rawName, isFirst ? 18 : 15),
                      )
                    : _buildInitialsText(rawName, isFirst ? 18 : 15),
              ),
            ),
            // Floating Rank Badge (#1, #2, #3)
            Positioned(
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: isFirst ? 11 : 9.5,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Podium Pillar Card
        Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: pillarBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    line1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: isFirst ? 12 : 11,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (line2.isNotEmpty)
                    Text(
                      line2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: isFirst ? 12 : 11,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Points Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF2E8B57), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          '$points pts',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: isFirst ? 11 : 10,
                            color: const Color(0xFF2E8B57),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Title Ribbon Pill (Champion, Master, Elite)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tagLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: tagTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsText(String name, double fontSize) {
    return Center(
      child: Text(
        _getInitials(name),
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ),
    );
  }

  Widget _buildRankCard(Map<String, dynamic> user, int index) {
    final rank = user['rank'] ?? 0;
    final name = user['name']?.toString() ?? 'Customer';
    final points = user['points']?.toString() ?? '0';
    final tier = user['tier']?.toString() ?? 'Diamond';
    final username = user['username']?.toString() ??
        name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').replaceAll(RegExp(r'_+'), '_');
    final tierColor = _getTierColor(tier);
    final avatarColor = _getAvatarBg(name, index);

    return InkWell(
      onTap: () => _showUserProfileModal(user),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Colorful User Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor,
              ),
              child: ClipOval(
                child: user['profile_image'] != null && user['profile_image'].toString().isNotEmpty
                    ? Image.network(
                        user['profile_image'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildInitialsText(name, 13),
                      )
                    : _buildInitialsText(name, 13),
              ),
            ),
            const SizedBox(width: 12),

            // Name on top, mini @username and Diamond Tier badge side-by-side below it
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@$username',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.diamond_outlined, size: 9, color: tierColor),
                            const SizedBox(width: 2),
                            Text(
                              tier,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: tierColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Points Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFF2E8B57), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$points pts',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: const Color(0xFF2E8B57),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyUserRankBar(Map<String, dynamic>? currentUserStats) {
    final userRank = currentUserStats?['globalRank']?.toString() ?? '5002';
    final userPoints = currentUserStats?['points']?.toString() ?? '0';
    final tier = currentUserStats?['tier']?.toString() ?? 'Bronze';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // User Rank Trophy Icon
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 20),
            ),
            const SizedBox(width: 12),

            // Rank Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Your Rank: #$userRank',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tier,
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You have $userPoints loyalty points',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E8B57),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Shop More',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
