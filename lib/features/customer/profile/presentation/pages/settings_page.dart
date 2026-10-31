import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';
import 'package:app/features/customer/profile/presentation/pages/personal_info_page.dart';
import 'package:app/features/customer/profile/presentation/pages/saved_addresses_page.dart';
import 'package:app/features/customer/profile/presentation/pages/payment_methods_page.dart';
import 'package:app/features/customer/support/presentation/pages/help_support_page.dart';
import 'package:app/features/customer/support/presentation/pages/about_us_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;

  Future<void> _confirmAndLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Log Out of Dovan?',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Are you sure you want to sign out from your account? You will need to log in again to view your orders and points.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
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
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Yes, Log Out',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final authRepo = CubePod.get<AuthRepository>();
      await authRepo.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Logged out successfully!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            backgroundColor: const Color(0xFF185B3A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = CubePod.get<AuthRepository>();

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
            'Settings',
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
          centerTitle: true,
        ),
        body: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: authRepo.authStateNotifier,
          builder: (context, currentUser, _) {
            final isLoggedIn = currentUser != null;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.paddingOf(context).bottom + 60,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // ── Account Section ──
                _buildSectionHeader('Account', 'Manage your account and payment details'),
                const SizedBox(height: 8),
                _buildCard([
                  _buildTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    subtitle: 'View and edit your profile details',
                    onTap: () => _navigateToProtected(const PersonalInfoPage()),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.location_on_outlined,
                    title: 'Saved Addresses',
                    subtitle: 'Manage your saved addresses',
                    onTap: () => _navigateToProtected(const SavedAddressesPage()),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.credit_card_outlined,
                    title: 'Payment Methods',
                    subtitle: 'Add or manage payment methods',
                    onTap: () => _navigateTo(const PaymentMethodsPage()),
                  ),
                ]),

                const SizedBox(height: 18),

                // ── Preferences Section ──
                _buildSectionHeader('Preferences', 'Customize your app experience'),
                const SizedBox(height: 8),
                _buildCard([
                  _buildTile(
                    icon: Icons.notifications_none_outlined,
                    title: 'Push Notifications',
                    subtitle: 'Stay updated with orders and offers',
                    trailing: Switch.adaptive(
                      value: _pushNotifications,
                      activeTrackColor: const Color(0xFF185B3A),
                      onChanged: (v) => setState(() => _pushNotifications = v),
                    ),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    subtitle: 'Select your preferred language',
                    trailingText: 'English',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 18),

                // ── Support Section ──
                _buildSectionHeader('Support', 'Get help and learn more about us'),
                const SizedBox(height: 8),
                _buildCard([
                  _buildTile(
                    icon: Icons.headphones_outlined,
                    title: 'Help Center',
                    subtitle: 'Get help with orders and more',
                    onTap: () => _navigateTo(const HelpSupportPage()),
                  ),
                  _buildDivider(),
                  _buildTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Us',
                    subtitle: 'Learn more about Dovan',
                    onTap: () => _navigateTo(const AboutUsPage()),
                  ),
                ]),

                const SizedBox(height: 18),

                // ── Log Out / Log In Card ──
                if (isLoggedIn)
                  _buildLogoutCard()
                else
                  _buildLoginCard(),

                const SizedBox(height: 24),
                _buildFooter(),
              ],
            ),
          );
          },
        ),
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _navigateToProtected(Widget page) {
    if (CubePod.get<AuthRepository>().isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 64, right: 16),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0xFF185B3A).withValues(alpha: 0.08),
        highlightColor: const Color(0xFF185B3A).withValues(alpha: 0.04),
        hoverColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5EE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: const Color(0xFF185B3A), size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF185B3A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              ],
              if (trailing == null && trailingText == null)
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEE2E2), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _confirmAndLogout,
            splashColor: const Color(0xFFE11D48).withValues(alpha: 0.08),
            highlightColor: const Color(0xFFE11D48).withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Out',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Sign out from your account',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFE11D48)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF185B3A).withValues(alpha: 0.2), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateTo(const AuthPage()),
            splashColor: const Color(0xFF185B3A).withValues(alpha: 0.08),
            highlightColor: const Color(0xFF185B3A).withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.login_rounded, color: Color(0xFF185B3A), size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log In / Sign Up',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF185B3A),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Sign in to access your profile & orders',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF185B3A)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF185B3A)),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
            children: [
              const TextSpan(text: 'Your privacy and data are '),
              TextSpan(
                text: '100% secure',
                style: GoogleFonts.outfit(color: const Color(0xFF185B3A), fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' with us.'),
            ],
          ),
        ),
      ],
    );
  }
}
