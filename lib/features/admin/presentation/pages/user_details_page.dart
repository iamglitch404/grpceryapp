import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/admin/presentation/pages/edit_account_page.dart';
import 'package:app/features/admin/presentation/pages/user_session_page.dart';
import 'package:app/features/admin/presentation/pages/user_activity_page.dart';

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailsPage({super.key, required this.user});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _usernameCtrl;

  bool _isLoading = false;
  late String _currentRole;
  late String _currentStatus;
  String? _selectedGender;

  List<dynamic> _orders = [];
  List<dynamic> _sessions = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['name'] ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email'] ?? '');
    _usernameCtrl = TextEditingController(text: widget.user['username'] ?? '');
    _currentRole = (widget.user['role'] ?? 'customer').toString().toLowerCase();
    _currentStatus = (widget.user['status'] ?? 'active').toString().toLowerCase();
    _selectedGender = widget.user['gender']?.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUserActivity() async {
    final userId = widget.user['id'];
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/users/$userId/activity'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders = data['orders'] ?? [];
          _sessions = data['sessions'] ?? [];
          _stats = data['stats'] ?? {};
        });
      }
    } catch (e) {
      debugPrint('[AdminUserDetails] Error fetching activity: $e');
    }
  }

  Future<void> _openEditAccountInfoPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountPage(
          user: widget.user,
          initialName: _nameCtrl.text,
          initialGender: _selectedGender,
          role: _currentRole,
          status: _currentStatus,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (result['name'] != null) _nameCtrl.text = result['name'];
        if (result.containsKey('gender')) _selectedGender = result['gender'];
      });
    }
  }

  void _openUserSessionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserSessionPage(
          user: widget.user,
          sessions: _sessions,
        ),
      ),
    );
  }

  void _openActivityPage(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserActivityPage(
          user: widget.user,
          initialCategory: category,
        ),
      ),
    );
  }

  Future<void> _saveUserDetails() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'id': widget.user['id'],
        'name': _nameCtrl.text.trim(),
        'gender': _selectedGender,
        'status': _currentStatus,
        'role': _currentRole,
      };

      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/users'),
        headers: {
          ...CubePod.get<AuthRepository>().authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile updated successfully'), backgroundColor: Color(0xFF185B3A)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update user profile'), backgroundColor: Colors.red),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUserAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete User Account?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete this user? All their orders, addresses, and history will be deleted.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            child: Text('Delete Account', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final userId = widget.user['id'];
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/users?id=$userId'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdjustPointsSheet() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isCredit = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adjust Loyalty Points', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Current Balance: ${_stats['points_balance'] ?? 0} Pts', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCredit = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCredit ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0), width: isCredit ? 1.5 : 1),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 16, color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('Add Points (+)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: isCredit ? FontWeight.bold : FontWeight.w600, color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCredit = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isCredit ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0), width: !isCredit ? 1.5 : 1),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_circle_outline_rounded, size: 16, color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('Deduct Points (-)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: !isCredit ? FontWeight.bold : FontWeight.w600, color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Points Amount', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 100, 250, 500',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Reason / Description', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. VIP Bonus, Referral Reward, Compensation',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCredit ? const Color(0xFF185B3A) : const Color(0xFFE11D48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                            final reason = reasonCtrl.text.trim();
                            if (amt <= 0 || reason.isEmpty) return;

                            final delta = isCredit ? amt : -amt;
                            setModalState(() => isSubmitting = true);
                            try {
                              final res = await http.post(
                                Uri.parse('${AppConfig.apiUrl}/admin/users/points'),
                                headers: {
                                  ...CubePod.get<AuthRepository>().authHeaders,
                                  'Content-Type': 'application/json',
                                },
                                body: jsonEncode({
                                  'user_id': widget.user['id'],
                                  'delta': delta,
                                  'reason': reason,
                                }),
                              );
                              if (mounted && ctx.mounted) {
                                Navigator.pop(ctx);
                                if (res.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isCredit ? '$amt points granted successfully' : '$amt points deducted'),
                                      backgroundColor: isCredit ? const Color(0xFF185B3A) : const Color(0xFFE11D48),
                                    ),
                                  );
                                  _fetchUserActivity();
                                }
                              }
                            } catch (_) {}
                          },
                    icon: isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isSubmitting ? 'Updating...' : (isCredit ? 'Credit Points' : 'Deduct Points'),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRolePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            Text('Change User Role', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _buildRoleOption('Customer / Shopper', 'customer', Icons.person_outline_rounded),
            _buildRoleOption('Store Administrator', 'admin', Icons.shield_outlined),
            _buildRoleOption('Delivery Driver', 'delivery_man', Icons.local_shipping_outlined),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            Text('Change Account Status', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _buildStatusOption('Active (Normal Access)', 'active', Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
            _buildStatusOption('Inactive (Suspended Temporarily)', 'inactive', Icons.pause_circle_outline_rounded, const Color(0xFFD97706)),
            _buildStatusOption('Suspended / Banned', 'suspended', Icons.block_rounded, const Color(0xFFE11D48)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(String label, String roleKey, IconData icon) {
    final isSelected = _currentRole == roleKey;
    return GestureDetector(
      onTap: () {
        setState(() => _currentRole = roleKey);
        Navigator.pop(context);
        _saveUserDetails();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
            Icon(icon, color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String label, String statusKey, IconData icon, Color color) {
    final isSelected = _currentStatus == statusKey;
    return GestureDetector(
      onTap: () {
        setState(() => _currentStatus = statusKey);
        Navigator.pop(context);
        _saveUserDetails();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF64748B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _showNotificationComposer() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedType = 'system';
    bool isSending = false;
    final targetName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : (_emailCtrl.text.isNotEmpty ? _emailCtrl.text : 'User');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Push Notification', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Sending to: $targetName', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Notification Title', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Account Notice / Special Offer',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Message Details', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type message...',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
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
                            if (title.isEmpty || body.isEmpty) return;

                            setModalState(() => isSending = true);
                            try {
                              final res = await http.post(
                                Uri.parse('${AppConfig.apiUrl}/notifications'),
                                headers: {
                                  ...CubePod.get<AuthRepository>().authHeaders,
                                  'Content-Type': 'application/json',
                                },
                                body: jsonEncode({
                                  'user_id': widget.user['id'],
                                  'title': title,
                                  'body': body,
                                  'type': selectedType,
                                }),
                              );
                              if (mounted && ctx.mounted) {
                                Navigator.pop(ctx);
                                if (res.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Notification sent to $targetName'), backgroundColor: const Color(0xFF185B3A)),
                                  );
                                  _fetchUserActivity();
                                }
                              }
                            } catch (_) {}
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
        ),
      ),
    );
  }

  String _formatDateTime(dynamic dtString) {
    if (dtString == null || dtString.toString().trim().isEmpty) return 'Not recorded';
    try {
      final dt = DateTime.parse(dtString.toString()).toLocal();
      final year = dt.year;
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hourNum = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$year-$month-$day • $hourNum:$min $period';
    } catch (_) {
      return dtString.toString().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.user['avatar_url'] ?? widget.user['profile_image'];
    final name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User';
    final username = widget.user['username'] ?? '';
    final provider = (widget.user['provider'] ?? 'EMAIL').toString().toUpperCase();

    Color roleBg = const Color(0xFFEFF6FF);
    Color roleText = const Color(0xFF2563EB);
    String roleDisplay = 'CUSTOMER';

    if (_currentRole == 'admin') {
      roleBg = const Color(0xFFFAF5FF);
      roleText = const Color(0xFF9333EA);
      roleDisplay = 'ADMIN';
    } else if (_currentRole.contains('delivery')) {
      roleBg = const Color(0xFFFFFBEB);
      roleText = const Color(0xFFD97706);
      roleDisplay = 'DELIVERY';
    }

    Color statusBg = const Color(0xFFDCFCE7);
    Color statusBorder = const Color(0xFF86EFAC);
    Color statusText = const Color(0xFF15803D);
    Color statusDot = const Color(0xFF16A34A);
    String statusDisplay = 'ACTIVE';

    if (_currentStatus == 'suspended' || _currentStatus == 'banned') {
      statusBg = const Color(0xFFFEE2E2);
      statusBorder = const Color(0xFFFCA5A5);
      statusText = const Color(0xFFB91C1C);
      statusDot = const Color(0xFFE11D48);
      statusDisplay = 'SUSPENDED';
    } else if (_currentStatus == 'inactive') {
      statusBg = const Color(0xFFF1F5F9);
      statusBorder = const Color(0xFFCBD5E1);
      statusText = const Color(0xFF64748B);
      statusDot = const Color(0xFF94A3B8);
      statusDisplay = 'INACTIVE';
    }

    final pointsBalance = _stats['points_balance'] ?? 0;
    final loyaltyTier = (_stats['tier'] ?? 'Bronze').toString();
    final totalSpentMoney = _stats['total_spent_money'] ?? 0;
    final totalOrdersCount = _stats['total_orders_count'] ?? _orders.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
                ),
              ),
            ),
          ),
          title: Text(
            'User Profile',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              child: ElevatedButton.icon(
                onPressed: _openEditAccountInfoPage,
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                label: Text('Edit', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading)
              const LinearProgressIndicator(
                color: Color(0xFF185B3A),
                backgroundColor: Color(0xFFDCFCE7),
                minHeight: 2.5,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // 1. Hero Identity Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Big Avatar
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                          ),
                          child: ClipOval(
                            child: avatar != null && avatar.toString().isNotEmpty
                                ? Image.network(
                                    avatar.toString(),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 26, color: const Color(0xFF185B3A)),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 26, color: const Color(0xFF185B3A)),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name + Badges + Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),

                              // Interactive Badges Row (Status + Role)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  // Status Badge (Tap to change)
                                  InkWell(
                                    onTap: _showStatusPicker,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusBg,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusBorder),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(color: statusDot, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusDisplay,
                                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusText, letterSpacing: 0.3),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: statusText),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Role Badge (Tap to change)
                                  InkWell(
                                    onTap: _showRolePicker,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: roleBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            roleDisplay,
                                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: roleText, letterSpacing: 0.3),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: roleText),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Username + Provider Row
                              Row(
                                children: [
                                  if (username.isNotEmpty)
                                    Text(
                                      '@$username',
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF185B3A)),
                                    ),
                                  if (username.isNotEmpty) const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          provider.contains('GOOGLE')
                                              ? Icons.g_mobiledata_rounded
                                              : (provider.contains('APPLE') ? Icons.apple_rounded : Icons.mail_outline_rounded),
                                          size: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          provider,
                                          style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _emailCtrl.text.isNotEmpty ? _emailCtrl.text : 'No email provided',
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
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),

                    // Quick Actions Row: Harmonized, cohesive, clear
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickActionTile(
                          icon: Icons.notifications_active_outlined,
                          label: 'Notify',
                          color: const Color(0xFF185B3A),
                          onTap: _showNotificationComposer,
                        ),
                        _buildQuickActionTile(
                          icon: Icons.stars_rounded,
                          label: 'Points',
                          color: const Color(0xFFD97706),
                          onTap: _showAdjustPointsSheet,
                        ),
                        _buildQuickActionTile(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Role',
                          color: const Color(0xFF7C3AED),
                          onTap: _showRolePicker,
                        ),
                        _buildQuickActionTile(
                          icon: Icons.shield_outlined,
                          label: 'Status',
                          color: const Color(0xFF16A34A),
                          onTap: _showStatusPicker,
                        ),
                        _buildQuickActionTile(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          color: const Color(0xFFDC2626),
                          onTap: _deleteUserAccount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Executive Financial & Loyalty Metrics Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF185B3A), Color(0xFF0F3D27)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF185B3A).withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text('Customer Lifetime & Rewards', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '$loyaltyTier Member'.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFFFDE68A), letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _buildMetricPill('Points', '$pointsBalance Pts', Icons.stars_rounded, const Color(0xFFFDE68A)),
                        const SizedBox(width: 8),
                        _buildMetricPill('Total Spent', 'Rs $totalSpentMoney', Icons.account_balance_wallet_outlined, Colors.white),
                        const SizedBox(width: 8),
                        _buildMetricPill('Total Orders', '$totalOrdersCount', Icons.shopping_bag_outlined, Colors.white),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const SizedBox(height: 20),

              // 3. User Settings & System Records
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'ACCOUNT & SECURITY',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    // Item 1: Account Information & Credentials
                    Material(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: InkWell(
                        onTap: _openEditAccountInfoPage,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF185B3A)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Information',
                                      style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User'} • ${_selectedGender ?? 'Not specified'} • Password',
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 1, indent: 70, color: Color(0xFFF1F5F9)),

                    // Item 2: Session & Security Logs
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openUserSessionPage,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.security_rounded, size: 20, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session & Audit Logs',
                                      style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Active ${_formatDateTime(widget.user['last_login_at'])} • Joined ${_formatDateTime(widget.user['created_at']).split('•').first.trim()}',
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(height: 1, indent: 70, color: Color(0xFFF1F5F9)),

                    // Item 3: Notifications & Alert Logs
                    Material(
                      color: Colors.transparent,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                      child: InkWell(
                        onTap: () => _openActivityPage('notifications'),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFF7C3AED)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Notifications & Alert Logs',
                                      style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'See sent notifications, alerts & delivery messages',
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Activity & Records Grouped Buttons
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'ACTIVITY & RECORDS',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _buildActivityButtonRow(
                      icon: Icons.shopping_bag_outlined,
                      iconBg: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF185B3A),
                      title: 'Orders & Purchases',
                      subtitle: 'Orders, purchases & payment history',
                      onTap: () => _openActivityPage('orders'),
                      isFirst: true,
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.stars_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'Points & Rewards Ledger',
                      subtitle: 'Loyalty points balance & transaction ledger',
                      onTap: () => _openActivityPage('points'),
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.shopping_cart_outlined,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF2563EB),
                      title: 'Active Shopping Cart',
                      subtitle: 'Current cart items & pending checkout',
                      onTap: () => _openActivityPage('cart'),
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.notifications_active_outlined,
                      iconBg: const Color(0xFFFAF5FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Direct Push Notifications',
                      subtitle: 'Direct notifications & sent messages',
                      onTap: () => _openActivityPage('notifications'),
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.location_on_outlined,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      title: 'Saved Delivery Addresses',
                      subtitle: 'Shipping addresses & recipient details',
                      onTap: () => _openActivityPage('addresses'),
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.rate_review_outlined,
                      iconBg: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: 'Product Reviews & Ratings',
                      subtitle: 'Customer reviews & product feedback',
                      onTap: () => _openActivityPage('reviews'),
                    ),
                    const Divider(height: 1, indent: 68, color: Color(0xFFF1F5F9)),
                    _buildActivityButtonRow(
                      icon: Icons.favorite_outline_rounded,
                      iconBg: const Color(0xFFFFF1F2),
                      iconColor: const Color(0xFFE11D48),
                      title: 'Saved Wishlist & Favorites',
                      subtitle: 'Saved products & bookmarked items',
                      onTap: () => _openActivityPage('favorites'),
                      isLast: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    ],
  ),
),
);
}

  Widget _buildQuickActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButtonRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(18) : Radius.zero,
        bottom: isLast ? const Radius.circular(18) : Radius.zero,
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(18) : Radius.zero,
          bottom: isLast ? const Radius.circular(18) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminUserDetailsPage = UserDetailsPage;
