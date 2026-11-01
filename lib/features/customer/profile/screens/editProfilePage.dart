import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  Map<String, dynamic> get _profileData => ref.watch(editProfileStateProvider);
  String get _name => _profileData['name']?.toString() ?? '';
  String get _username => _profileData['username']?.toString() ?? '';
  String get _email => _profileData['email']?.toString() ?? '';
  String get _phone => _profileData['phone']?.toString() ?? '';
  String? get _avatarUrl => _profileData['profile_image'] ?? _profileData['avatar_url'];
  XFile? get _selectedAvatarImage => ref.watch(editProfileAvatarProvider);
  String get _gender => _profileData['gender']?.toString() ?? 'Not selected';
  String get _genderPreference => _profileData['genderPreference']?.toString() ?? 'Not selected';
  bool get _isLoading => ref.watch(editProfileLoadingProvider);

  void _setField(String key, dynamic value) {
    ref.read(editProfileStateProvider.notifier).state = {
      ...ref.read(editProfileStateProvider),
      key: value,
    };
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;
      ref.read(editProfileStateProvider.notifier).state = {
        'name': user?['name']?.toString() ?? '',
        'username': user?['username']?.toString() ?? '',
        'email': user?['email']?.toString() ?? '',
        'phone': user?['phone']?.toString() ?? '',
        'profile_image': user?['profile_image'] ?? user?['avatar_url'],
        'gender': user?['gender']?.toString() ?? 'Not selected',
        'genderPreference': 'Not selected',
      };

      if (authRepo.isLoggedIn) {
        _loadProfileData();
      }
    });
  }

  Future<void> _loadProfileData() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isLoggedIn) return;
    final userRepo = ref.read(userRepositoryProvider);

    try {
      final profile = await userRepo.fetchMyProfile(authRepo.authHeaders);
      if (mounted) {
        final current = Map<String, dynamic>.from(ref.read(editProfileStateProvider));
        if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
          current['name'] = profile['name'].toString();
        }
        if (profile['username'] != null && profile['username'].toString().isNotEmpty) {
          current['username'] = profile['username'].toString();
        }
        if (profile['email'] != null && profile['email'].toString().isNotEmpty) {
          current['email'] = profile['email'].toString();
        }
        if (profile['phone'] != null) {
          current['phone'] = profile['phone'].toString();
        }
        if (profile['gender'] != null && profile['gender'].toString().isNotEmpty) {
          current['gender'] = profile['gender'].toString();
        }
        if (profile['profile_image'] != null && profile['profile_image'].toString().isNotEmpty) {
          current['profile_image'] = profile['profile_image'].toString();
        }
        ref.read(editProfileStateProvider.notifier).state = current;
      }
    } catch (e) {
      debugPrint('[EditProfilePage] Error loading profile: $e');
    }
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (image != null && mounted) {
      ref.read(editProfileAvatarProvider.notifier).state = image;
    }
  }

  Future<void> _saveAllChanges() async {
    final authRepo = ref.read(authRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);
    final user = authRepo.currentUser;

    final trimmedName = _name.trim();
    final trimmedUsername = _username.trim().toLowerCase();
    final trimmedPhone = _phone.trim();
    final trimmedGender = _gender.trim();

    if (trimmedName.isEmpty) {
      _showToast('Please enter your full name', isError: true);
      return;
    }

    if (trimmedUsername.isNotEmpty && trimmedUsername.length < 3) {
      _showToast('Username must be at least 3 characters', isError: true);
      return;
    }

    ref.read(editProfileLoadingProvider.notifier).state = true;

    try {
      String? finalAvatarUrl = _avatarUrl;

      // 1. Upload Avatar if selected
      if (_selectedAvatarImage != null) {
        final bytes = await _selectedAvatarImage!.readAsBytes();
        final uploadedUrl = await userRepo.uploadAvatar(
          authRepo.authHeaders,
          bytes,
          _selectedAvatarImage!.name,
        );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalAvatarUrl = uploadedUrl;
        }
      }

      // 2. Submit Updates
      final Map<String, dynamic> updates = {
        'name': trimmedName,
      };

      if (trimmedUsername.isNotEmpty) {
        updates['username'] = trimmedUsername;
      }
      if (trimmedPhone.isNotEmpty) {
        updates['phone'] = trimmedPhone;
      }
      if (trimmedGender.isNotEmpty) {
        updates['gender'] = trimmedGender;
      }
      if (finalAvatarUrl != null && finalAvatarUrl.isNotEmpty) {
        updates['profile_image'] = finalAvatarUrl;
      }

      final success = await userRepo.updateProfile(authRepo.authHeaders, updates);

      if (!success) {
        throw Exception('Profile update failed. The username might already be taken.');
      }

      // 3. Update session caches
      final updatedUser = {
        ...?user,
        ...updates,
        'profile_image': ?finalAvatarUrl,
      };
      authRepo.currentUser = updatedUser;
      authRepo.authStateNotifier.value = updatedUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(updatedUser));

      if (mounted) {
        _showToast('Profile updated successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[EditProfilePage] Save Error: $e');
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (mounted) _showToast(msg, isError: true);
    } finally {
      if (mounted) ref.read(editProfileLoadingProvider.notifier).state = false;
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF185B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEditFieldModal({
    required String title,
    required String initialValue,
    required String hintText,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
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
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Edit $title',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  if (prefixText != null) ...[
                    Text(
                      prefixText,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF185B3A),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      inputFormatters: inputFormatters,
                      autofocus: true,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final val = controller.text.trim();
                      if (val.isNotEmpty) {
                        Navigator.pop(ctx);
                        onSave(val);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGenderSelectionModal() {
    final options = ['Male', 'Female', 'Other', 'Prefer not to say'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
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
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select Gender',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            ...options.map((opt) {
              final isSelected = _gender == opt;
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _setField('gender', opt);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opt,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF185B3A), size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.read(authRepositoryProvider);
    final isLoggedIn = authRepo.isLoggedIn;
    final initials = _name.isNotEmpty
        ? _name.substring(0, 1).toUpperCase()
        : (_username.isNotEmpty ? _username.substring(0, 1).toUpperCase() : 'U');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF9),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: const Color(0xFFF8FAF9),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            if (isLoggedIn)
              TextButton(
                onPressed: _isLoading ? null : _saveAllChanges,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF185B3A)),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF185B3A),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: !isLoggedIn
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5EE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_outlined,
                          size: 56,
                          color: Color(0xFF185B3A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sign In Required',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need to be signed in to edit your profile details.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          color: const Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185B3A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AuthPage()),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: Text(
                            'Log In / Sign Up',
                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
          Expanded(
            child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                    children: [
                      // ── 1. Centered Profile Avatar Section ──
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFE8F5EE),
                                    ),
                                    child: ClipOval(
                                      child: _selectedAvatarImage != null
                                          ? (kIsWeb
                                              ? Image.network(_selectedAvatarImage!.path, fit: BoxFit.cover)
                                              : Image.file(File(_selectedAvatarImage!.path), fit: BoxFit.cover))
                                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                              ? Image.network(
                                                  _avatarUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => _buildAvatarInitial(initials),
                                                )
                                              : _buildAvatarInitial(initials)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(5.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF185B3A),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickAvatar,
                              child: Text(
                                'Change photo',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF185B3A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 2. BASIC DETAILS ──
                      _buildSectionTitle('BASIC DETAILS'),
                      const SizedBox(height: 6),
                      _buildCard([
                        _buildRowTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Full Name',
                          value: _name,
                          onTap: () {
                            _showEditFieldModal(
                              title: 'Full Name',
                              initialValue: _name,
                              hintText: 'Enter your full name',
                              onSave: (val) => _setField('name', val),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildRowTile(
                          icon: Icons.alternate_email_rounded,
                          label: 'Username',
                          value: _username,
                          badge: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF185B3A), size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  'Available',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF185B3A),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          helperText: 'Username can only contain letters, numbers and dots.',
                          onTap: () {
                            _showEditFieldModal(
                              title: 'Username',
                              initialValue: _username,
                              hintText: 'Enter username',
                              prefixText: '@',
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                                LengthLimitingTextInputFormatter(30),
                              ],
                              onSave: (val) => _setField('username', val),
                            );
                          },
                        ),
                        _buildDivider(),
                        _buildRowTile(
                          icon: Icons.face_rounded,
                          label: 'Gender',
                          value: _gender,
                          onTap: _showGenderSelectionModal,
                        ),
                        _buildDivider(),
                        _buildRowTile(
                          icon: Icons.visibility_off_outlined,
                          label: 'Prefer not to say',
                          value: _genderPreference,
                          valueColor: const Color(0xFF64748B),
                          onTap: () {
                            _showEditFieldModal(
                              title: 'Gender Preference',
                              initialValue: _genderPreference == 'Not selected' ? '' : _genderPreference,
                              hintText: 'e.g. Custom preference',
                              onSave: (val) => _setField('genderPreference', val),
                            );
                          },
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── 3. CONTACT INFORMATION ──
                      _buildSectionTitle('CONTACT INFORMATION'),
                      const SizedBox(height: 6),
                      _buildCard([
                        _buildRowTile(
                          icon: Icons.mail_outline_rounded,
                          label: 'Email Address',
                          value: _email,
                          badge: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF185B3A), size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF185B3A),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            _showToast('Email address is verified & secured.');
                          },
                        ),
                        _buildDivider(),
                        _buildRowTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone Number',
                          value: _phone.isNotEmpty ? _phone : 'Not added yet',
                          valueColor: _phone.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          trailingActionText: _phone.isEmpty ? 'Add' : null,
                          onTap: () {
                            _showEditFieldModal(
                              title: 'Phone Number',
                              initialValue: _phone,
                              hintText: 'Enter mobile number',
                              keyboardType: TextInputType.phone,
                              onSave: (val) => _setField('phone', val),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // Alert Card
                        InkWell(
                          onTap: () {
                            _showEditFieldModal(
                              title: 'Phone Number',
                              initialValue: _phone,
                              hintText: 'Enter mobile number',
                              keyboardType: TextInputType.phone,
                              onSave: (val) => _setField('phone', val),
                            );
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Color(0xFF185B3A), size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add your phone number for better security',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        "We'll use it to secure your account and send important updates.",
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF185B3A), size: 18),
                              ],
                            ),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // ── 4. ACCOUNT SECURITY ──
                      _buildSectionTitle('ACCOUNT SECURITY'),
                      const SizedBox(height: 6),
                      _buildCard([
                        _buildRowTile(
                          icon: Icons.lock_outline_rounded,
                          label: 'Password',
                          value: '••••••••',
                          onTap: () {
                            _showToast('Password reset link can be sent to your email.');
                          },
                        ),
                      ]),
                    ],
                  ),
                ),

                // ── Bottom Fixed Save Changes Button ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAF9),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveAllChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185B3A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildAvatarInitial(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF185B3A),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildRowTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? badge,
    String? trailingActionText,
    String? helperText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5EE),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, size: 17, color: const Color(0xFF185B3A)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: valueColor ?? const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  badge,
                  const SizedBox(width: 8),
                ],
                if (trailingActionText != null) ...[
                  Text(
                    trailingActionText,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF185B3A),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
            if (helperText != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  helperText,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 12, thickness: 1, color: Color(0xFFF1F5F9));
  }
}
