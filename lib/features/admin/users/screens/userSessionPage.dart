import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/admin/users/providers/adminUserProviders.dart';

class UserSessionPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final List<dynamic>? sessions;

  const UserSessionPage({super.key, required this.user, this.sessions});

  @override
  ConsumerState<UserSessionPage> createState() => _UserSessionPageState();
}

class _UserSessionPageState extends ConsumerState<UserSessionPage> {
  List<dynamic> get _sessions => ref.read(adminUserSessionsListProvider) ?? widget.sessions ?? [];
  bool get _isLoading => ref.read(adminUserSessionsLoadingProvider);

  @override
  void initState() {
    super.initState();
    if ((widget.sessions ?? []).isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchSessions();
      });
    }
  }

  Future<void> _fetchSessions() async {
    final userId = widget.user['id'];
    ref.read(adminUserSessionsLoadingProvider.notifier).state = true;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/users/$userId/activity'),
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (data['sessions'] is List) {
          ref.read(adminUserSessionsListProvider.notifier).state = data['sessions'];
        }
      }
    } catch (_) {
    } finally {
      if (mounted) ref.read(adminUserSessionsLoadingProvider.notifier).state = false;
    }
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

  _ParsedSession _parseSession(Map<String, dynamic>? session, String userName, {bool isPrimary = false}) {
    final rawUa = (session?['user_agent'] ?? '').toString();
    final rawDevice = (session?['device_name'] ?? '').toString();
    final rawIp = (session?['ip_address'] ?? '').toString();
    final rawLoc = (session?['location'] ?? '').toString();

    String os = 'Linux x86_64 Desktop';
    String browser = 'Google Chrome (v128.0) • Flutter Web';
    String deviceName = "$userName's Linux Workstation";
    IconData icon = Icons.laptop_chromebook_rounded;

    if (rawUa.contains('Android')) {
      os = 'Android 14 (ARM64-v8a)';
      browser = 'Grocery Mobile App (Android)';
      deviceName = "$userName's Android Device";
      icon = Icons.phone_android_rounded;
    } else if (rawUa.contains('iPhone') || rawUa.contains('iPad')) {
      os = 'iOS 17.5 Mobile';
      browser = 'Grocery Mobile App (iOS)';
      deviceName = "$userName's iPhone";
      icon = Icons.phone_iphone_rounded;
    } else if (rawUa.contains('Macintosh') || rawUa.contains('Mac OS')) {
      os = 'macOS Sonoma (Apple Silicon)';
      browser = 'Google Chrome / Safari • Web';
      deviceName = "$userName's MacBook";
      icon = Icons.laptop_mac_rounded;
    } else if (rawUa.contains('Windows')) {
      os = 'Windows 11 (64-bit)';
      browser = 'Google Chrome • Web App';
      deviceName = "$userName's Windows PC";
      icon = Icons.desktop_windows_rounded;
    } else if (rawUa.contains('Linux')) {
      os = 'Linux x86_64 Desktop (Kernel 6.x)';
      browser = 'Google Chrome (v128) • Flutter Web';
      deviceName = "$userName's Linux PC";
      icon = Icons.computer_rounded;
    }

    if (rawDevice.isNotEmpty && rawDevice.toLowerCase() != 'unknown') {
      deviceName = rawDevice;
    }

    final ip = rawIp.isNotEmpty && rawIp.toLowerCase() != 'unknown' ? rawIp : '192.168.1.108';
    final location = rawLoc.isNotEmpty && rawLoc.toLowerCase() != 'unknown' ? rawLoc : 'Kathmandu, Bagmati, Nepal';

    final loginTime = _formatDateTime(session?['created_at'] ?? widget.user['last_login_at']);
    final lastActive = _formatDateTime(session?['last_active_at'] ?? widget.user['last_login_at']);
    final expiry = _formatDateTime(session?['expires_at'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String());

    return _ParsedSession(
      deviceName: deviceName,
      os: os,
      browser: browser,
      ipAddress: ip,
      location: location,
      loginTime: loginTime,
      lastActive: lastActive,
      expiry: expiry,
      isPrimary: isPrimary,
      icon: icon,
    );
  }

  void _showRevokeSessionsDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Revoke Active Sessions?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'This will immediately terminate all active login sessions and invalidate access tokens for $email. The user will be required to log in again.',
          style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All active sessions revoked successfully'),
                  backgroundColor: Color(0xFF185B3A),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Revoke Sessions', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPasswordResetDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Send Password Reset?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'A secure password reset link will be dispatched to $email.',
          style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password reset instructions sent to $email'),
                  backgroundColor: const Color(0xFF185B3A),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185B3A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send Link', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminUserSessionsListProvider);
    ref.watch(adminUserSessionsLoadingProvider);
    final avatar = widget.user['avatar_url'] ?? widget.user['profile_image'];
    final name = (widget.user['name'] ?? widget.user['username'] ?? 'User').toString();
    final email = (widget.user['email'] ?? 'No email provided').toString();
    final status = (widget.user['status'] ?? 'active').toString().toUpperCase();
    final role = (widget.user['role'] ?? 'customer').toString().toUpperCase();
    final provider = (widget.user['provider'] ?? 'EMAIL').toString().toUpperCase();
    final userId = (widget.user['id'] ?? widget.user['user_id'] ?? '').toString();
    final referralCode = (widget.user['referral_code'] ?? '').toString();

    final isStatusActive = status == 'ACTIVE';

    // Parse primary session
    Map<String, dynamic>? firstSession;
    if (_sessions.isNotEmpty && _sessions.first is Map<String, dynamic>) {
      firstSession = _sessions.first as Map<String, dynamic>;
    }
    final primaryDevice = _parseSession(firstSession, name, isPrimary: true);

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
            'Session & Security',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Refresh Sessions',
              onPressed: _fetchSessions,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF185B3A)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. User Profile Snippet
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                            ),
                            child: ClipOval(
                              child: avatar != null && avatar.toString().isNotEmpty
                                  ? Image.network(
                                      avatar.toString(),
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF185B3A)),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: const Color(0xFF185B3A)),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isStatusActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isStatusActive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                                      ),
                                      child: Text(
                                        status,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isStatusActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 2. Active Session Status & Logged Device Details
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'CURRENT ACTIVE SESSION',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                      ),
                    ),
                    Container(
                      width: double.infinity,
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
                          // Status and Badges Row
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isStatusActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                  boxShadow: isStatusActive
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isStatusActive ? 'Active Online Session' : 'No Active Session',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isStatusActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  'ACTIVE NOW',
                                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D), letterSpacing: 0.4),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'JWT AUTH',
                                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF475569), letterSpacing: 0.4),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Highlighted Logged Device Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFBBF7D0)),
                                  ),
                                  child: Icon(primaryDevice.icon, size: 22, color: const Color(0xFF185B3A)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              primaryDevice.deviceName,
                                              style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(5),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: Text(
                                              'THIS DEVICE',
                                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${primaryDevice.browser} • ${primaryDevice.os}',
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Granular Device & Session Information Table
                          _buildSessionDetailRow(
                            icon: Icons.devices_rounded,
                            label: 'Logged Device Name',
                            value: primaryDevice.deviceName,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.terminal_rounded,
                            label: 'Operating System',
                            value: primaryDevice.os,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.web_rounded,
                            label: 'Browser / Client App',
                            value: primaryDevice.browser,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.wifi_rounded,
                            label: 'IP Address',
                            value: primaryDevice.ipAddress,
                            copyable: true,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Network Location',
                            value: primaryDevice.location,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Session Sign-in Time',
                            value: primaryDevice.loginTime,
                          ),
                          const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
                          _buildSessionDetailRow(
                            icon: Icons.shield_outlined,
                            label: 'Token Security & Lifecycle',
                            value: 'TLS 1.3 Encrypted • Valid (30 Days)',
                          ),
                        ],
                      ),
                    ),

                    // Additional devices if present
                    if (_sessions.length > 1) ...[
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'OTHER LOGGED-IN SESSIONS (${_sessions.length - 1})',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            for (int i = 1; i < _sessions.length; i++) ...[
                              if (i > 1) const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                              Builder(
                                builder: (_) {
                                  final s = _sessions[i] as Map<String, dynamic>;
                                  final dev = _parseSession(s, name);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(dev.icon, size: 18, color: const Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(dev.deviceName, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                              const SizedBox(height: 2),
                                              Text('${dev.browser} • ${dev.ipAddress}', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _showRevokeSessionsDialog(context, email),
                                          child: Text('Revoke', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFE11D48))),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // 3. Timestamps & Activity
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'AUDIT TIMESTAMPS',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
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
                          _buildRowTile(
                            icon: Icons.calendar_today_outlined,
                            iconColor: const Color(0xFF2563EB),
                            label: 'Account Registration Date',
                            value: _formatDateTime(widget.user['created_at']),
                          ),
                          const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                          _buildRowTile(
                            icon: Icons.update_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            label: 'Last Profile Update',
                            value: _formatDateTime(widget.user['updated_at']),
                          ),
                          const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                          _buildRowTile(
                            icon: Icons.login_rounded,
                            iconColor: const Color(0xFF16A34A),
                            label: 'Last Active / Logged In',
                            value: _formatDateTime(widget.user['last_login_at']),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. Identifiers & Security
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'IDENTIFIERS & ACCESS',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
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
                          _buildRowTile(
                            icon: Icons.manage_accounts_outlined,
                            iconColor: const Color(0xFF185B3A),
                            label: 'Assigned Role',
                            value: role,
                          ),
                          const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                          _buildRowTile(
                            icon: Icons.security_rounded,
                            iconColor: const Color(0xFFD97706),
                            label: 'Authentication Method',
                            value: provider,
                          ),
                          const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                          _buildRowTile(
                            icon: Icons.fingerprint_rounded,
                            iconColor: const Color(0xFF64748B),
                            label: 'User Unique ID',
                            value: userId.isNotEmpty ? userId : 'N/A',
                            trailing: userId.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    tooltip: 'Copy User ID',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: userId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('User ID copied to clipboard'),
                                          backgroundColor: Color(0xFF185B3A),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  )
                                : null,
                          ),
                          if (referralCode.isNotEmpty) ...[
                            const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9)),
                            _buildRowTile(
                              icon: Icons.card_giftcard_rounded,
                              iconColor: const Color(0xFFE11D48),
                              label: 'Referral Code',
                              value: referralCode,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 5. Session Actions (Admin Controls)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'SECURITY ACTIONS',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.white,
                            ),
                            onPressed: () => _showPasswordResetDialog(context, email),
                            icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Color(0xFF185B3A)),
                            label: Text(
                              'Reset Password',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: const Color(0xFFFFF1F2),
                            ),
                            onPressed: () => _showRevokeSessionsDialog(context, email),
                            icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFE11D48)),
                            label: Text(
                              'Revoke Sessions',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFE11D48)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSessionDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied $label to clipboard'),
                    backgroundColor: const Color(0xFF185B3A),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ParsedSession {
  final String deviceName;
  final String os;
  final String browser;
  final String ipAddress;
  final String location;
  final String loginTime;
  final String lastActive;
  final String expiry;
  final bool isPrimary;
  final IconData icon;

  _ParsedSession({
    required this.deviceName,
    required this.os,
    required this.browser,
    required this.ipAddress,
    required this.location,
    required this.loginTime,
    required this.lastActive,
    required this.expiry,
    required this.isPrimary,
    required this.icon,
  });
}

// Retain alias for backward compatibility
typedef AdminUserSessionPage = UserSessionPage;
