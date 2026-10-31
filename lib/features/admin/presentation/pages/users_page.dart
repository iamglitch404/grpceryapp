import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/admin/presentation/pages/user_details_page.dart';

class UsersPage extends StatefulWidget {
  final String? initialFilter;
  const UsersPage({super.key, this.initialFilter});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';
  late String _selectedRoleFilter;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedRoleFilter = widget.initialFilter ?? 'All';
    _fetchUsers(showFullLoading: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({bool showFullLoading = false}) async {
    if (showFullLoading || _users.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/users'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        List<dynamic> parsedList = [];
        if (data is List) {
          parsedList = data;
        } else if (data is Map) {
          parsedList = data['data'] is List
              ? data['data']
              : (data['users'] is List ? data['users'] : []);
        }

        setState(() {
          _users = parsedList;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching users: $e');
    }
  }

  List<dynamic> get _filteredUsers {
    List<dynamic> list = List.from(_users);

    if (_selectedRoleFilter != 'All') {
      final target = _selectedRoleFilter.toLowerCase();
      list = list.where((u) {
        final r = (u['role'] ?? 'user').toString().toLowerCase();
        if (target == 'admins') return r == 'admin';
        if (target == 'customers') return r == 'user' || r == 'customer';
        if (target == 'delivery' || target == 'deliveryman') return r.contains('delivery');
        return true;
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((u) {
        final name = (u['name'] ?? u['full_name'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final username = (u['username'] ?? '').toString().toLowerCase();
        final phone = (u['phone'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || username.contains(q) || phone.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _updateUserRole(dynamic userId, String currentName, String newRole) async {
    HapticFeedback.mediumImpact();
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/users'),
        headers: CubePod.get<AuthRepository>().authHeaders,
        body: jsonEncode({
          'id': userId,
          'name': currentName,
          'role': newRole,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to $newRole successfully'),
            backgroundColor: const Color(0xFF185B3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchUsers();
      } else {
        debugPrint('Error updating user: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
  }

  Future<void> _deleteUser(dynamic id, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete User Account?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete account "$userName"? This action is permanent and cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF475569)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/users?id=$id'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account deleted'),
            backgroundColor: Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchUsers();
      }
    } catch (e) {
      debugPrint('Error deleting user: $e');
    }
  }

  void _showRoleSheet(Map<String, dynamic> user) {
    final userId = user['id'];
    final name = user['name'] ?? user['full_name'] ?? 'User';
    String currentRole = (user['role'] ?? 'user').toString().toLowerCase();
    if (currentRole == 'user') currentRole = 'customer';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Change Account Role',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              Text(
                'Assign role for $name',
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildRoleTile('Customer / Shopper', 'customer', 'Standard shopper with store purchasing access', Icons.person_outline_rounded, currentRole, userId, name),
              _buildRoleTile('Store Administrator', 'admin', 'Full access to products, metrics, and banners', Icons.shield_outlined, currentRole, userId, name),
              _buildRoleTile('Delivery Driver', 'delivery_man', 'Access to order dispatch and status delivery', Icons.local_shipping_outlined, currentRole, userId, name),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleTile(String label, String roleKey, String subtitle, IconData icon, String currentRole, dynamic userId, String name) {
    final isSelected = currentRole == roleKey;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (!isSelected) {
          _updateUserRole(userId, name, roleKey);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ],
        ),
      ),
    );
  }

  void _showSendNotificationDialog(Map<String, dynamic>? user, {bool isGlobal = false}) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedType = 'system';
    bool isSending = false;

    final targetName = isGlobal ? 'All Registered Users' : (user?['name'] ?? user?['email'] ?? 'User');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGlobal ? 'Broadcast Announcement' : 'Send Push Notification',
                              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              'Recipient: $targetName',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notification Type Selector
                  Text('Notification Category', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTypeChip('System ℹ️', 'system', selectedType, (t) => setModalState(() => selectedType = t)),
                      _buildTypeChip('Promo 🏷️', 'promo', selectedType, (t) => setModalState(() => selectedType = t)),
                      _buildTypeChip('Order 📦', 'order', selectedType, (t) => setModalState(() => selectedType = t)),
                      _buildTypeChip('Alert ⚠️', 'alert', selectedType, (t) => setModalState(() => selectedType = t)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title input
                  Text('Notification Title', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. Special Weekend Deal / Account Notice',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message body input
                  Text('Message Body', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 3,
                    style: GoogleFonts.outfit(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type your message details here...',
                      hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185B3A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              final body = bodyCtrl.text.trim();
                              if (title.isEmpty || body.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please provide both title and message')),
                                );
                                return;
                              }

                              setModalState(() => isSending = true);
                              try {
                                final payload = {
                                  'title': title,
                                  'body': body,
                                  'type': selectedType,
                                  if (isGlobal) 'is_global': true else 'user_id': user?['id'],
                                };

                                final res = await http.post(
                                  Uri.parse('${AppConfig.apiUrl}/notifications'),
                                  headers: {
                                    ...CubePod.get<AuthRepository>().authHeaders,
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode(payload),
                                );

                                if (mounted && ctx.mounted) {
                                  Navigator.pop(ctx);
                                  if (res.statusCode == 200) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isGlobal ? 'Broadcast sent to all users!' : 'Notification sent to $targetName'),
                                        backgroundColor: const Color(0xFF185B3A),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to deliver notification'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              } finally {
                                setModalState(() => isSending = false);
                              }
                            },
                      icon: isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isSending ? 'Sending...' : 'Send Notification',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUserAddressesSheet(Map<String, dynamic> user) {
    final targetName = user['name'] ?? user['email'] ?? 'User';
    final userId = user['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_outlined, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved Delivery Addresses', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      Text('User: $targetName', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<http.Response>(
                future: http.get(
                  Uri.parse('${AppConfig.apiUrl}/admin/users/$userId/activity'),
                  headers: CubePod.get<AuthRepository>().authHeaders,
                ),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)));
                  }
                  if (snap.hasError || snap.data?.statusCode != 200) {
                    return Center(
                      child: Text('Failed to load addresses', style: GoogleFonts.outfit(color: Colors.red)),
                    );
                  }
                  final data = jsonDecode(snap.data!.body);
                  final addresses = (data['addresses'] ?? []) as List;

                  if (addresses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_off_outlined, size: 40, color: Color(0xFFCBD5E1)),
                          const SizedBox(height: 8),
                          Text('No saved addresses for this user', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final a = addresses[i];
                      final label = (a['label'] ?? 'Home').toString();
                      final isDefault = a['is_default'] == true;
                      final recName = a['name'] ?? '';
                      final phone = a['phone'] ?? '';
                      final street = a['street'] ?? '';
                      final details = a['details'] ?? '';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDefault ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                            width: isDefault ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            label.toLowerCase() == 'work' ? Icons.work_outline_rounded : Icons.home_outlined,
                                            size: 12,
                                            color: const Color(0xFF2563EB),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            label.toUpperCase(),
                                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (phone.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(phone, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (recName.isNotEmpty)
                              Text(
                                recName,
                                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                            Text(
                              street,
                              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155)),
                            ),
                            if (details.isNotEmpty)
                              Text(
                                details,
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String key, String selected, Function(String) onSelect) {
    final isSelected = selected == key;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF475569))),
      selected: isSelected,
      selectedColor: const Color(0xFF185B3A),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => onSelect(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredUsers;
    final canPop = Navigator.canPop(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          titleSpacing: canPop ? 0 : 20,
          title: Row(
            children: [
              Text(
                'Registered Users',
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
                  '${_users.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: Color(0xFF185B3A), size: 23),
              tooltip: 'Broadcast Announcement',
              onPressed: () => _showSendNotificationDialog(null, isGlobal: true),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            // Search Input & Filter Tabs Container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search by name, email, or phone...',
                              hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All'),
                        _buildFilterChip('Admins'),
                        _buildFilterChip('Customers'),
                        _buildFilterChip('Deliveryman'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Users List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.group_off_rounded, size: 42, color: Color(0xFF15803D)),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No users found',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty ? 'Try changing your search query' : 'No user records in this category',
                                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: const Color(0xFF185B3A),
                          onRefresh: _fetchUsers,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final u = filtered[index];
                              return _buildUserCard(u);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedRoleFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedRoleFilter = label);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
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
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final name = u['name'] ?? u['full_name'] ?? 'User';
    final email = u['email'] ?? 'No email provided';
    final phone = u['phone'] ?? u['phone_number'] ?? '';
    final username = u['username'] ?? '';
    final role = (u['role'] ?? 'customer').toString().toLowerCase();
    final avatar = u['avatar_url'] ?? u['profile_image'];
    final userId = u['id'];

    Color roleBg = const Color(0xFFEFF6FF);
    Color roleText = const Color(0xFF2563EB);
    String roleDisplay = 'CUSTOMER';

    if (role == 'admin') {
      roleBg = const Color(0xFFFAF5FF);
      roleText = const Color(0xFF9333EA);
      roleDisplay = 'ADMIN';
    } else if (role.contains('delivery')) {
      roleBg = const Color(0xFFFFFBEB);
      roleText = const Color(0xFFD97706);
      roleDisplay = 'DELIVERY';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserDetailsPage(user: u)),
            );
            if (mounted) {
              _fetchUsers(showFullLoading: false);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipOval(
                        child: avatar != null && avatar.toString().isNotEmpty
                            ? Image.network(
                                avatar.toString(),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF185B3A)),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF185B3A)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + Email + Role Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (u['status'] == 'suspended' || u['status'] == 'banned') ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  (u['status'] ?? 'ACTIVE').toString().toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: (u['status'] == 'suspended' || u['status'] == 'banned') ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: roleBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleDisplay,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: roleText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
                                ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  (u['provider'] ?? 'EMAIL').toString().toUpperCase(),
                                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                                ),
                              ),
                              if (u['points_balance'] != null && (u['points_balance'] as num) > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars_rounded, size: 10, color: Color(0xFFD97706)),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${u['points_balance']} Pts',
                                        style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showUserAddressesSheet(u),
                      icon: const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF059669)),
                      label: Text(
                        'Addresses',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _showSendNotificationDialog(u),
                      icon: const Icon(Icons.notifications_active_outlined, size: 15, color: Color(0xFF2563EB)),
                      label: Text(
                        'Notify',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _showRoleSheet(u),
                      icon: const Icon(Icons.manage_accounts_outlined, size: 15, color: Color(0xFF185B3A)),
                      label: Text(
                        'Role',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF185B3A)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _deleteUser(userId, name),
                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFE11D48)),
                      label: Text(
                        'Delete',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFE11D48)),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef ManageUsersPage = UsersPage;
