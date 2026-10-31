import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'dart:async';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';

class AllUsersPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialUsers;
  const AllUsersPage({super.key, this.initialUsers = const []});

  @override
  State<AllUsersPage> createState() => _AllUsersPageState();
}

class _AllUsersPageState extends State<AllUsersPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  late AnimationController _skeletonController;
  late Animation<Color?> _skeletonColorAnimation;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 50;

  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  String _selectedTier = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonColorAnimation = ColorTween(
      begin: const Color(0xFFF1F5F9),
      end: const Color(0xFFE2E8F0),
    ).animate(CurvedAnimation(
      parent: _skeletonController,
      curve: Curves.easeInOut,
    ));

    if (widget.initialUsers.isNotEmpty) {
      _users = List.from(widget.initialUsers);
      _offset = _users.length;
      _hasMore = _users.length >= _limit;
    } else {
      _fetchInitialUsers();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _skeletonController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (!_isLoadingMore && !_isLoading && _hasMore) {
        _fetchMoreUsers();
      }
    }
  }

  Future<void> _fetchInitialUsers() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMore = true;
    });

    try {
      final headers = CubePod.get<AuthRepository>().authHeaders;
      final data = await CubePod.get<UserRepository>().fetchLeaderboard(
        headers,
        limit: _limit,
        offset: 0,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        tier: _selectedTier != 'All' ? _selectedTier : null,
      );

      if (mounted) {
        final parsed = _mapRawUsers(data);
        setState(() {
          _users = parsed;
          _offset = parsed.length;
          _hasMore = parsed.length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AllUsersPage] Error fetching initial users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreUsers() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final headers = CubePod.get<AuthRepository>().authHeaders;
      final data = await CubePod.get<UserRepository>().fetchLeaderboard(
        headers,
        limit: _limit,
        offset: _offset,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        tier: _selectedTier != 'All' ? _selectedTier : null,
      );

      if (mounted) {
        final parsed = _mapRawUsers(data);
        setState(() {
          _users.addAll(parsed);
          _offset += parsed.length;
          _hasMore = parsed.length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('[AllUsersPage] Error loading more users: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<Map<String, dynamic>> _mapRawUsers(List<dynamic> data) {
    return data.map((u) {
      final pts = u['points'] is int ? u['points'] : int.tryParse(u['points']?.toString() ?? '0') ?? 0;
      final rawName = u['name']?.toString() ?? 'Customer';
      final username = u['username']?.toString() ??
          rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').replaceAll(RegExp(r'_+'), '_');

      return {
        'rank': u['rank'] ?? 0,
        'user_id': u['user_id']?.toString() ?? '',
        'name': rawName,
        'username': username,
        'profile_image': u['profile_image']?.toString(),
        'points': pts,
        'tier': u['tier']?.toString() ?? _getTierFromPoints(pts),
      };
    }).toList();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchQuery = query.trim());
      _fetchInitialUsers();
    });
  }

  void _onTierSelected(String tier) {
    setState(() => _selectedTier = tier);
    _fetchInitialUsers();
  }

  static String _getTierFromPoints(int points) {
    if (points >= 2500) return 'Diamond';
    if (points >= 1000) return 'Platinum';
    if (points >= 500) return 'Gold';
    if (points >= 200) return 'Silver';
    return 'Bronze';
  }

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
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          top: false,
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
                    width: 76,
                    height: 76,
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
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
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
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${user['username'] ?? 'shopper'}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
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
                        fontSize: 11.5,
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
      ),
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

  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _skeletonColorAnimation,
      builder: (context, _) {
        final shimmer = _skeletonColorAnimation.value ?? const Color(0xFFF1F5F9);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          ),
          child: Row(
            children: [
              // Rank Box Skeleton
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),

              // Avatar Skeleton
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shimmer,
                ),
              ),
              const SizedBox(width: 12),

              // Name & Tier Skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),

              // Points Pill Skeleton
              Container(
                width: 72,
                height: 24,
                decoration: BoxDecoration(
                  color: shimmer,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
              'All Ranked Users',
              style: GoogleFonts.outfit(
                color: const Color(0xFF185B3A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              _isLoading
                  ? 'Searching shoppers...'
                  : '${_users.length} shoppers loaded',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // ── Search Box ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                style: GoogleFonts.outfit(fontSize: 14),
                decoration: InputDecoration(
                  icon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                  hintText: 'Search user name or rank #...',
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13.5),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Tier Filter Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze'].map((tier) {
                final isSelected = _selectedTier == tier;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tier),
                    selected: isSelected,
                    onSelected: (_) => _onTierSelected(tier),
                    selectedColor: const Color(0xFF185B3A),
                    backgroundColor: const Color(0xFFF8FAFC),
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── User Cards Infinite Scroll List with Shimmer Skeleton Loader ──
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: 8,
                    itemBuilder: (context, index) => _buildSkeletonCard(),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No users found matching "$_searchQuery"',
                          style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _users.length + (_hasMore ? 3 : 0),
                        itemBuilder: (context, index) {
                          // Render Skeleton Loaders for items after current batch
                          if (index >= _users.length) {
                            return _buildSkeletonCard();
                          }

                          final u = _users[index];
                          final rank = u['rank'] ?? 0;
                          final name = u['name']?.toString() ?? 'Customer';
                          final points = u['points']?.toString() ?? '0';
                          final tier = u['tier']?.toString() ?? 'Bronze';
                          final tierColor = _getTierColor(tier);
                          final avatarColor = _getAvatarBg(name, index);

                          return InkWell(
                            onTap: () => _showUserProfileModal(u),
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
                                      color: rank <= 3
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#$rank',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: rank <= 3
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Colorful Avatar
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: avatarColor,
                                    ),
                                    child: ClipOval(
                                      child: u['profile_image'] != null && u['profile_image'].toString().isNotEmpty
                                          ? Image.network(
                                              u['profile_image'],
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
                                                '@${u['username'] ?? ''}',
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
