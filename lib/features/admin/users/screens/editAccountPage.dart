import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/admin/users/providers/adminUserProviders.dart';

class EditAccountPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final String initialName;
  final String? initialGender;
  final String role;
  final String status;

  const EditAccountPage({
    super.key,
    required this.user,
    required this.initialName,
    this.initialGender,
    required this.role,
    required this.status,
  });

  @override
  ConsumerState<EditAccountPage> createState() => _EditAccountPageState();
}

class _EditAccountPageState extends ConsumerState<EditAccountPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();

  String? get _selectedGender => ref.read(adminEditAccountGenderProvider(widget.initialGender));
  bool get _obscurePassword => ref.read(adminEditAccountObscurePasswordProvider);
  bool get _isSaving => ref.read(adminEditAccountSavingProvider);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _usernameCtrl = TextEditingController(text: widget.user['username']?.toString() ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAccountInfo() async {
    final updatedName = _nameCtrl.text.trim();
    if (updatedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    ref.read(adminEditAccountSavingProvider.notifier).state = true;

    try {
      final body = <String, dynamic>{
        'id': widget.user['id'],
        'name': updatedName,
        'gender': _selectedGender,
        'status': widget.status,
        'role': widget.role,
      };

      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/users'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account information updated successfully'),
              backgroundColor: Color(0xFF185B3A),
            ),
          );
          Navigator.pop(context, {
            'name': updatedName,
            'gender': _selectedGender,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update account information'),
              backgroundColor: Colors.red,
            ),
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
      if (mounted) ref.read(adminEditAccountSavingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminEditAccountGenderProvider(widget.initialGender));
    ref.watch(adminEditAccountObscurePasswordProvider);
    ref.watch(adminEditAccountSavingProvider);
    final avatar = widget.user['avatar_url'] ?? widget.user['profile_image'];
    final name = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'User';

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
            'Account Information',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAccountInfo,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                label: Text('Save', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Profile Snippet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                      ),
                      child: ClipOval(
                        child: avatar != null && avatar.toString().isNotEmpty
                            ? Image.network(
                                avatar.toString(),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: const Color(0xFF185B3A)),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22, color: const Color(0xFF185B3A)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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
              ),

              const SizedBox(height: 16),

              // 2. The Form Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF185B3A)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Account Information', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                            Text('Edit credentials & user profile details', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInputField('Full Name', _nameCtrl, Icons.person_outline_rounded, hint: 'User Full Name'),
                    _buildInputField('Username', _usernameCtrl, Icons.alternate_email_rounded, hint: 'username_handle', readOnly: true),
                    _buildInputField(
                      'Email Address',
                      _emailCtrl,
                      Icons.mail_outline_rounded,
                      hint: 'email@example.com',
                      readOnly: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                        tooltip: 'Copy Email',
                        onPressed: () {
                          if (_emailCtrl.text.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _emailCtrl.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied "${_emailCtrl.text}" to clipboard'),
                                backgroundColor: const Color(0xFF185B3A),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    _buildGenderField(),
                    _buildInputField(
                      'Reset Password',
                      _passwordCtrl,
                      Icons.lock_outline_rounded,
                      hint: 'Leave blank to keep current',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF94A3B8)),
                        onPressed: () => ref.read(adminEditAccountObscurePasswordProvider.notifier).state = !_obscurePassword,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Primary Save Button at Bottom
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _isSaving ? null : _saveAccountInfo,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _isSaving ? 'Saving Changes...' : 'Save Account Changes',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    String? hint,
    bool readOnly = false,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
              if (readOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Read-only', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            readOnly: readOnly,
            obscureText: obscureText,
            style: GoogleFonts.outfit(fontSize: 13.5, color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: readOnly ? const Color(0xFF94A3B8) : const Color(0xFF185B3A), size: 18),
              suffixIcon: suffixIcon,
              hintText: hint,
              hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    final genders = ['Male', 'Female', 'Other', 'Not specified'];
    final currentVal = _selectedGender != null && _selectedGender!.isNotEmpty ? _selectedGender! : 'Not specified';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: genders.contains(currentVal) ? currentVal : 'Not specified',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                onChanged: (val) {
                  ref.read(adminEditAccountGenderProvider(widget.initialGender).notifier).state =
                      val == 'Not specified' ? null : val;
                },
                items: genders.map((g) {
                  IconData icon = Icons.person_outline_rounded;
                  if (g == 'Male') icon = Icons.male_rounded;
                  if (g == 'Female') icon = Icons.female_rounded;
                  if (g == 'Other') icon = Icons.transgender_rounded;

                  return DropdownMenuItem<String>(
                    value: g,
                    child: Row(
                      children: [
                        Icon(icon, size: 16, color: const Color(0xFF185B3A)),
                        const SizedBox(width: 8),
                        Text(g, style: GoogleFonts.outfit(fontSize: 13.5)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminEditAccountInfoPage = EditAccountPage;
