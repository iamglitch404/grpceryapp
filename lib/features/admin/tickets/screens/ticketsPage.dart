import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/di/injection.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/admin/tickets/providers/adminTicketProviders.dart';
import 'package:app/features/admin/tickets/widgets/adminTicketCard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketsPage extends ConsumerStatefulWidget {
  const TicketsPage({super.key});

  @override
  ConsumerState<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends ConsumerState<TicketsPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> get _tickets => ref.read(adminTicketsListProvider);
  bool get _isLoading => ref.read(adminTicketsLoadingProvider);
  bool get _isFetchingFresh => ref.read(adminTicketsFetchingFreshProvider);
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  static const _cacheKey = 'admin_tickets_cache_v1';

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    _loadCacheThenFetch();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCacheThenFetch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> cachedList = jsonDecode(cached);
        if (mounted && cachedList.isNotEmpty) {
          ref.read(adminTicketsListProvider.notifier).state = cachedList;
          ref.read(adminTicketsLoadingProvider.notifier).state = false;
          _fetchFreshTickets(silent: true);
          return;
        }
      }
    } catch (_) {}
    _fetchFreshTickets(silent: false);
  }

  Widget _buildSkeletonList() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final opacity = _shimmerAnim.value;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildSkeletonCard(opacity),
        );
      },
    );
  }

  Widget _buildSkeletonCard(double opacity) {
    Widget shimmerBox(double w, double h, {double radius = 8}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  shimmerBox(28, 28, radius: 8),
                  const SizedBox(width: 8),
                  shimmerBox(80, 12),
                  const SizedBox(width: 8),
                  shimmerBox(90, 20, radius: 6),
                ],
              ),
              shimmerBox(64, 22, radius: 12),
            ],
          ),
          const SizedBox(height: 14),
          shimmerBox(double.infinity, 13),
          const SizedBox(height: 8),
          shimmerBox(double.infinity, 52, radius: 10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shimmerBox(140, 11),
              shimmerBox(96, 11),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchFreshTickets({bool silent = false}) async {
    if (!silent && mounted) ref.read(adminTicketsLoadingProvider.notifier).state = true;
    if (silent && mounted) ref.read(adminTicketsFetchingFreshProvider.notifier).state = true;
    try {
      final headers = ref.read(authRepositoryProvider).authHeaders;
      final results = await Future.wait([
        http.get(Uri.parse('${AppConfig.apiUrl}/tickets'), headers: headers),
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/users'), headers: headers),
      ]);

      final ticketsRes = results[0];
      final usersRes = results[1];

      Map<String, Map<String, dynamic>> userMap = {};
      if (usersRes.statusCode == 200) {
        final uData = jsonDecode(usersRes.body);
        final uList = uData is List ? uData : (uData['data'] ?? uData['users'] ?? []);
        if (uList is List) {
          for (final u in uList) {
            if (u is Map) {
              final uid = (u['id'] ?? u['account_id'] ?? u['user_id'])?.toString();
              if (uid != null && uid.isNotEmpty) userMap[uid] = Map<String, dynamic>.from(u);
              final aid = u['account_id']?.toString();
              if (aid != null && aid.isNotEmpty) userMap[aid] = Map<String, dynamic>.from(u);
            }
          }
        }
      }

      if (ticketsRes.statusCode == 200) {
        final data = jsonDecode(ticketsRes.body);
        final list = data['tickets'] ?? data['data'] ?? [];
        if (list is List) {
          final enriched = list.map((t) {
            if (t is! Map) return t;
            final map = Map<String, dynamic>.from(t);
            final accId = (map['account_id'] ?? map['user_id'])?.toString();
            final userInfo = accId != null ? userMap[accId] : null;

            final existingName = map['customer_name']?.toString();
            final existingEmail = map['customer_email']?.toString();
            final existingPhone = map['customer_phone']?.toString();

            final name = (existingName != null && existingName.isNotEmpty && existingName.toLowerCase() != 'customer')
                ? existingName
                : (userInfo?['name'] ?? userInfo?['username'] ?? 'Customer');
            final email = (existingEmail != null && existingEmail.isNotEmpty)
                ? existingEmail
                : (userInfo?['email'] ?? '');
            String phone = (existingPhone != null && existingPhone.isNotEmpty)
                ? existingPhone
                : (userInfo?['phone'] ?? '');
            if (phone.isEmpty) {
              final msg = (map['message'] ?? '').toString();
              final match = RegExp(r'(\b98\d{8}\b|\b97\d{8}\b|\b\d{10}\b)').firstMatch(msg);
              if (match != null) phone = match.group(1) ?? '';
            }
            map['customer_name'] = name;
            map['customer_email'] = email;
            map['customer_phone'] = phone;
            return map;
          }).toList();

          // Persist to local cache
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, jsonEncode(enriched));
          } catch (_) {}

          if (mounted) {
            final currentTickets = ref.read(adminTicketsListProvider);
            List<dynamic> updatedList;
            if (silent && currentTickets.isNotEmpty) {
              // Merge: brand-new tickets float to the top
              final existingIds = <String, bool>{};
              for (final t in currentTickets) {
                final id = t['id']?.toString();
                if (id != null) existingIds[id] = true;
              }
              final newOnes = enriched
                  .where((t) => !existingIds.containsKey(t['id']?.toString()))
                  .toList();
              final updatedMap = <String, dynamic>{};
              for (final t in enriched) {
                final id = t['id']?.toString();
                if (id != null) updatedMap[id] = t;
              }
              updatedList = [
                ...newOnes,
                ...currentTickets.map((t) => updatedMap[t['id']?.toString()] ?? t),
              ];
            } else {
              updatedList = enriched;
            }
            ref.read(adminTicketsListProvider.notifier).state = updatedList;
            ref.read(adminTicketsLoadingProvider.notifier).state = false;
            ref.read(adminTicketsFetchingFreshProvider.notifier).state = false;
          }
          return;
        }
      }
      if (mounted) {
        ref.read(adminTicketsLoadingProvider.notifier).state = false;
        ref.read(adminTicketsFetchingFreshProvider.notifier).state = false;
      }
    } catch (e) {
      debugPrint('[TicketsPage] error: $e');
      if (mounted) {
        ref.read(adminTicketsLoadingProvider.notifier).state = false;
        ref.read(adminTicketsFetchingFreshProvider.notifier).state = false;
      }
    }
  }

  /// Public pull-to-refresh — always a full (non-silent) reload.
  Future<void> _fetchTickets({bool silent = false}) =>
      _fetchFreshTickets(silent: silent);

  Future<void> _updateTicketStatus(String id, String newStatus) async {
    HapticFeedback.mediumImpact();

    // 1. Optimistic in-place update (instant UI change, zero spinner!)
    final tickets = List<dynamic>.from(ref.read(adminTicketsListProvider));
    final index = tickets.indexWhere((t) => t['id'] == id);
    if (index == -1) return;
    final oldStatus = tickets[index]['status'];

    final updatedTicket = Map<String, dynamic>.from(tickets[index]);
    updatedTicket['status'] = newStatus;
    if (newStatus == 'Resolved' || newStatus == 'Closed') {
      updatedTicket['resolved_at'] = DateTime.now().toIso8601String();
    }
    tickets[index] = updatedTicket;
    ref.read(adminTicketsListProvider.notifier).state = tickets;

    try {
      final headers = ref.read(authRepositoryProvider).authHeaders;
      final res = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/tickets'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'status': newStatus,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          AppToast.success(context, 'Ticket status updated to $newStatus');
          // 2. Silent background sync without resetting UI or showing spinner
          _fetchTickets(silent: true);
        }
      } else {
        // Revert on server error
        if (mounted) {
          final rollback = List<dynamic>.from(ref.read(adminTicketsListProvider));
          final idx = rollback.indexWhere((t) => t['id'] == id);
          if (idx != -1) {
            final t = Map<String, dynamic>.from(rollback[idx]);
            t['status'] = oldStatus;
            rollback[idx] = t;
            ref.read(adminTicketsListProvider.notifier).state = rollback;
          }
          AppToast.error(context, 'Failed to update ticket status. Reverted.');
        }
      }
    } catch (e) {
      debugPrint('[TicketsPage] update error: $e');
      if (mounted) {
        final rollback = List<dynamic>.from(ref.read(adminTicketsListProvider));
        final idx = rollback.indexWhere((t) => t['id'] == id);
        if (idx != -1) {
          final t = Map<String, dynamic>.from(rollback[idx]);
          t['status'] = oldStatus;
          rollback[idx] = t;
          ref.read(adminTicketsListProvider.notifier).state = rollback;
        }
      }
    }
  }

  int _getCountForFilter(String filter) {
    if (filter == 'All') return _tickets.length;
    return _tickets.where((t) {
      final s = (t['status'] ?? 'Open').toString().toLowerCase();
      return s == filter.toLowerCase();
    }).length;
  }

  List<dynamic> _filterTickets(String selectedFilter, String searchQuery, String sortBy) {
    var list = List<dynamic>.from(_tickets);

    // 1. Status Filter
    if (selectedFilter != 'All') {
      list = list.where((t) {
        final s = (t['status'] ?? 'Open').toString().toLowerCase();
        return s == selectedFilter.toLowerCase();
      }).toList();
    }

    // 2. Search Query Filter
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((t) {
        final id = (t['id'] ?? '').toString().toLowerCase();
        final name = (t['customer_name'] ?? '').toString().toLowerCase();
        final phone = (t['customer_phone'] ?? '').toString().toLowerCase();
        final email = (t['customer_email'] ?? '').toString().toLowerCase();
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final msg = (t['message'] ?? '').toString().toLowerCase();
        final status = (t['status'] ?? '').toString().toLowerCase();

        return id.contains(q) ||
            name.contains(q) ||
            phone.contains(q) ||
            email.contains(q) ||
            subject.contains(q) ||
            msg.contains(q) ||
            status.contains(q);
      }).toList();
    }

    // 3. Sort Order
    list.sort((a, b) {
      switch (sortBy) {
        case 'Oldest':
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
          return dateA.compareTo(dateB);

        case 'Status':
          int getRank(String s) {
            switch (s.toLowerCase()) {
              case 'open':
                return 0;
              case 'in progress':
                return 1;
              case 'resolved':
                return 2;
              case 'closed':
                return 3;
              default:
                return 4;
            }
          }
          final rankA = getRank(a['status']?.toString() ?? '');
          final rankB = getRank(b['status']?.toString() ?? '');
          if (rankA != rankB) return rankA.compareTo(rankB);
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
          return dateB.compareTo(dateA);

        case 'Name':
          final nameA = (a['customer_name'] ?? '').toString().toLowerCase();
          final nameB = (b['customer_name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);

        case 'Latest':
        default:
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
          return dateB.compareTo(dateA);
      }
    });

    return list;
  }

  void _showSortSheet(BuildContext context, String currentSortBy) {
    HapticFeedback.lightImpact();
    final sortOptions = [
      ('Latest', 'Latest First', Icons.schedule_rounded),
      ('Oldest', 'Oldest First', Icons.history_rounded),
      ('Status', 'Pending First', Icons.priority_high_rounded),
      ('Name', 'Customer (A-Z)', Icons.sort_by_alpha_rounded),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sort by',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortOptions.map((opt) {
                  final isSelected = currentSortBy == opt.$1;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(adminTicketSortProvider.notifier).state = opt.$1;
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt.$3,
                            size: 14,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opt.$2,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    ref.watch(adminTicketsListProvider);
    ref.watch(adminTicketsLoadingProvider);
    ref.watch(adminTicketsFetchingFreshProvider);
    final selectedFilter = ref.watch(adminTicketFilterProvider);
    final sortBy = ref.watch(adminTicketSortProvider);
    final searchQuery = ref.watch(adminTicketSearchQueryProvider);
    final filtered = _filterTickets(selectedFilter, searchQuery, sortBy);

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
        titleSpacing: 0,
        title: Row(
          children: [
            Text(
              'Customer Tickets',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_tickets.length}',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar & Filter/Sort Header — all one cohesive block
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              children: [
                // Search Bar only
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => ref.read(adminTicketSearchQueryProvider.notifier).state = val,
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Search tickets, customer, phone...',
                            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            ref.read(adminTicketSearchQueryProvider.notifier).state = '';
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 17),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Filter + Sort chips — all in ONE scrollable row
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Sort chip — same pill style as filter chips
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showSortSheet(context, sortBy),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: sortBy != 'Latest'
                                  ? const Color(0xFF185B3A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sortBy != 'Latest'
                                    ? const Color(0xFF185B3A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 13,
                                  color: sortBy != 'Latest' ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  sortBy == 'Latest' ? 'Sort' : sortBy,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: sortBy != 'Latest' ? FontWeight.w700 : FontWeight.w600,
                                    color: sortBy != 'Latest' ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: sortBy != 'Latest' ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Divider between sort and filter chips
                      Container(
                        width: 1,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8, top: 4),
                        color: const Color(0xFFE2E8F0),
                      ),
                      // Status filter chips
                      ...['All', 'Open', 'In Progress', 'Resolved', 'Closed'].map((filter) {
                        final isSelected = selectedFilter == filter;
                        final count = _getCountForFilter(filter);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref.read(adminTicketFilterProvider.notifier).state = filter;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  filter == 'All' && _tickets.isNotEmpty
                                      ? 'All (${_tickets.length})'
                                      : (count > 0 ? '$filter ($count)' : filter),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Thin gradient bar shown while silently refreshing with cached data
          if (_isFetchingFresh)
            Container(
              height: 2.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF185B3A), Color(0xFF4ADE80), Color(0xFF185B3A)],
                ),
              ),
            ),

          // Tickets List / Empty State
          Expanded(
            child: _isLoading
                ? _buildSkeletonList()
                : RefreshIndicator(
                    color: const Color(0xFF185B3A),
                    onRefresh: _fetchTickets,
                    child: filtered.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: searchQuery.isNotEmpty ? const Color(0xFFFEF2F2) : const Color(0xFFDCFCE7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.support_agent_rounded,
                                        size: 36,
                                        color: searchQuery.isNotEmpty ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      searchQuery.isNotEmpty
                                          ? 'No Tickets Found'
                                          : 'No ${selectedFilter == 'All' ? '' : selectedFilter} Tickets',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      child: Text(
                                        searchQuery.isNotEmpty
                                            ? 'No tickets match "$searchQuery". Try different keywords or clear the search.'
                                            : 'Customer requests and inquiries will show up here.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    if (searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          ref.read(adminTicketSearchQueryProvider.notifier).state = '';
                                        },
                                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF185B3A)),
                                        label: Text(
                                          'Clear Search',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF185B3A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final ticket = filtered[index] as Map<String, dynamic>;
                              return AdminTicketCard(
                                ticket: ticket,
                                onUpdateStatus: _updateTicketStatus,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef ManageTicketsPage = TicketsPage;
