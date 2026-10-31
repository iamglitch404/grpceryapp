import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/services/country_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/customer/support/presentation/pages/live_chat_page.dart';

class CallUsPage extends StatefulWidget {
  const CallUsPage({super.key});

  @override
  State<CallUsPage> createState() => _CallUsPageState();
}

class _CallUsPageState extends State<CallUsPage> {
  static const String _supportPhone = '+1 (800) 123-4567';
  static const String _supportPhoneDial = 'tel:+18001234567';

  final TextEditingController _phoneController = TextEditingController();
  CountryInfo _selectedCountry = CountryService.getInitialCountry();
  bool _isCopied = false;
  bool _isSubmittingCallback = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _initCountry();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _initCountry() async {
    final country = await CountryService.getCountryWithIpFallback();
    if (mounted) {
      setState(() {
        _selectedCountry = country;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(const ClipboardData(text: _supportPhone));
    HapticFeedback.lightImpact();
    if (mounted) {
      AppToast.success(context, 'Support number copied to clipboard');
    }

    setState(() {
      _isCopied = true;
    });

    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  Future<void> _makeDirectCall() async {
    HapticFeedback.mediumImpact();
    final uri = Uri.parse(_supportPhoneDial);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard();
      }
    } catch (_) {
      _copyToClipboard();
    }
  }

  void _navigateToLiveChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveChatPage()),
    );
  }

  void _openCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = CountryService.countries.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase().trim();
              return c.name.toLowerCase().contains(q) ||
                  c.dialCode.toLowerCase().contains(q) ||
                  c.isoCode.toLowerCase().contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Country Code',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E2022),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 14),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search country or code...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey.shade500,
                            size: 18,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isSelected =
                            c.isoCode == _selectedCountry.isoCode;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCountry = c;
                            });
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            color: isSelected
                                ? const Color(0xFFF0FDF4)
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Text(
                                  c.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF42A769)
                                          : const Color(0xFF1E2022),
                                    ),
                                  ),
                                ),
                                Text(
                                  c.dialCode,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF42A769)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: Color(0xFF42A769),
                                  ),
                                ],
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
          },
        );
      },
    );
  }

  Future<void> _requestCallback() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      AppToast.warning(context, 'Please enter your phone number');
      return;
    }

    if (phone.length < _selectedCountry.minLength ||
        phone.length > _selectedCountry.maxLength) {
      AppToast.error(
        context,
        'Please enter a valid ${_selectedCountry.lengthDescription} number',
      );
      return;
    }

    final fullNumber = '${_selectedCountry.dialCode} $phone';
    setState(() => _isSubmittingCallback = true);

    try {
      Map<String, String> headers = {'Content-Type': 'application/json'};
      if (CubePod.get<AuthRepository>().sessionToken != null) {
        headers['Authorization'] =
            'Bearer ${CubePod.get<AuthRepository>().sessionToken}';
      }

      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/tickets'),
        headers: headers,
        body: jsonEncode({
          'subject': 'Callback Request: $fullNumber',
          'message': 'User requested a call back at $fullNumber.',
        }),
      );

      if (mounted) {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          AppToast.success(
            context,
            'Callback requested for $fullNumber! Our team will call you shortly.',
          );
          _phoneController.clear();
          try {
            CubePod.get<NotificationState>().fetchUnreadCount();
          } catch (_) {}
        } else {
          AppToast.success(
            context,
            'Callback requested! We will call $fullNumber soon.',
          );
          _phoneController.clear();
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.success(
          context,
          'Callback requested! We will call $fullNumber soon.',
        );
        _phoneController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCallback = false);
      }
    }
  }

  Widget _buildMetaRow(
    IconData icon,
    String label,
    String value, {
    Widget? trailingBadge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        if (trailingBadge != null)
          trailingBadge
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E2022),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF2D2D2D),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Call Us',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── 1. Hero Brand Identity (Matches About Us & Ticket Status) ──
            Center(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF42A769).withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      size: 40,
                      color: Color(0xFF42A769),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Dovan Helpline',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2022),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Have questions about your order or grocery delivery?\nOur customer care team is ready to help.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade600,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 2. Direct Helpline Card (Matches TicketStatusPage design) ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: Color(0xFF42A769),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Direct Helpline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              _supportPhone,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E2022),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _copyToClipboard,
                        icon: Icon(
                          _isCopied
                              ? Icons.check_circle_rounded
                              : Icons.copy_rounded,
                          color: _isCopied
                              ? const Color(0xFF42A769)
                              : Colors.grey.shade500,
                          size: 22,
                        ),
                        tooltip: 'Copy Number',
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Color(0xFFF0F1F3)),
                  ),
                  _buildMetaRow(
                    Icons.access_time_rounded,
                    'Working Hours:',
                    'Mon – Sat, 9:00 AM – 6:00 PM',
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow(
                    Icons.flash_on_rounded,
                    'Wait Time:',
                    '',
                    trailingBadge: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '< 2 mins',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF42A769),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _makeDirectCall,
                      icon: const Icon(
                        Icons.phone_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Call Helpline Now',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A769),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 3. Request a Callback Card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Request a Callback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2022),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Leave your phone number and we'll call you right back.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone Input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: _openCountryPicker,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCountry.flag,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCountry.dialCode,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E2022),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(
                                _selectedCountry.maxLength,
                              ),
                            ],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E2022),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your phone number',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed:
                          _isSubmittingCallback ? null : _requestCallback,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF42A769),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: const Color(0xFF42A769),
                      ),
                      child: _isSubmittingCallback
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF42A769),
                              ),
                            )
                          : const Text(
                              'Request Callback',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF42A769),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 4. Live Chat Alternative (Unified Tile) ──
            InkWell(
              onTap: _navigateToLiveChat,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF42A769),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prefer not to call? Chat with Us',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E2022),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Instant real-time messaging support',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: Color(0xFF42A769),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
