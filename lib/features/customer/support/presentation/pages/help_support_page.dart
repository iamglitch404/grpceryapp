import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod/cubepod.dart';
import 'package:app/features/customer/support/presentation/pages/ticket_status_page.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/features/customer/support/presentation/pages/call_us_page.dart';
import 'package:app/features/customer/support/presentation/pages/live_chat_page.dart';
import 'package:app/features/auth/presentation/pages/login_page.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';
import 'package:app/core/widgets/bounce_button.dart';
import 'package:app/core/widgets/toast.dart';

class SupportAttachment {
  final String name;
  final String path;
  final int bytes;
  final bool isImage;
  final Uint8List? data;

  SupportAttachment({
    required this.name,
    required this.path,
    required this.bytes,
    required this.isImage,
    this.data,
  });

  String get formattedSize {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  List<Map<String, String>> _faqs = [];
  List<bool> _expandedStates = [];

  final List<Map<String, String>> _staticFaqs = [
    {
      'question': 'How long does delivery take?',
      'answer':
          'Standard delivery takes 30–45 mins. Express orders arrive within 30 mins.',
    },
    {
      'question': 'What are the delivery charges?',
      'answer':
          'FREE on orders above Rs 500. Standard delivery is Rs 50 for smaller orders.',
    },
    {
      'question': 'Can I return or exchange items?',
      'answer':
          'Report any quality or freshness issue within 24 hours for instant refund or replacement.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _faqs = _staticFaqs;
    _expandedStates = List<bool>.filled(_faqs.length, false);
  }

  final TextEditingController _messageController = TextEditingController();
  final List<SupportAttachment> _selectedAttachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;

  void _showLoginRequiredSheet([String action = 'submit a support ticket']) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 32,
                color: Color(0xFF185B3A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign In Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please sign in to $action so our support team can assist and follow up with your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF185B3A)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF185B3A)),
                title: const Text('Take a Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      _showLoginRequiredSheet('attach photos to your ticket');
      return;
    }
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        final data = await image.readAsBytes();
        final length = data.lengthInBytes;
        if (mounted) {
          setState(() {
            _selectedAttachments.add(
              SupportAttachment(
                name: image.name,
                path: image.path,
                bytes: length,
                isImage: true,
                data: data,
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      _showLoginRequiredSheet('attach files to your ticket');
      return;
    }
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles();
      if (files.isNotEmpty) {
        for (final f in files) {
          final isImg = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic']
              .contains(f.extension?.toLowerCase());
          Uint8List? fileData;
          try {
            fileData = await f.readAsBytes();
          } catch (_) {}
          final size = fileData?.lengthInBytes ?? (await f.length());
          if (mounted) {
            setState(() {
              _selectedAttachments.add(
                SupportAttachment(
                  name: f.name,
                  path: f.path ?? '',
                  bytes: size,
                  isImage: isImg,
                  data: fileData,
                ),
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file explorer: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;

    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      _showLoginRequiredSheet('submit a support ticket');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty && _selectedAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a message or attach a file/photo.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authRepo = CubePod.get<AuthRepository>();
      List<Map<String, dynamic>> uploadedAttachments = [];

      // Upload each attachment to the backend
      for (final att in _selectedAttachments) {
        try {
          final uri = Uri.parse('${AppConfig.apiUrl}/tickets/upload');
          final request = http.MultipartRequest('POST', uri);
          if (authRepo.sessionToken != null) {
            request.headers['Authorization'] = 'Bearer ${authRepo.sessionToken}';
          }
          final Uint8List fileBytes = att.data ??
              (att.path.isNotEmpty ? await File(att.path).readAsBytes() : Uint8List(0));
          if (fileBytes.isEmpty) continue;

          request.files.add(http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: att.name,
          ));

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final payload = data['data'] ?? data;
            if (payload['url'] != null) {
              uploadedAttachments.add({
                'url': payload['url'],
                'file_name': payload['file_name'] ?? att.name,
                'file_size': payload['file_size'] ?? att.bytes,
                'file_type': payload['file_type'] ?? (att.isImage ? 'image' : 'file'),
              });
            }
          }
        } catch (uploadErr) {
          debugPrint('Error uploading attachment ${att.name}: $uploadErr');
        }
      }

      Map<String, String> headers = {'Content-Type': 'application/json'};
      if (authRepo.sessionToken != null) {
        headers['Authorization'] = 'Bearer ${authRepo.sessionToken}';
      }

      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/tickets'),
        headers: headers,
        body: jsonEncode({
          'message': message.isNotEmpty ? message : 'Support request with attachment(s)',
          'attachments': uploadedAttachments,
        }),
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        AppToast.success(
          context,
          'Message sent! Our support team will get back to you soon.',
          title: 'Ticket Submitted',
        );
        _messageController.clear();
        setState(() {
          _selectedAttachments.clear();
          _isSubmitting = false;
        });
        try {
          CubePod.get<NotificationState>().fetchUnreadCount();
        } catch (_) {}
      } else {
        setState(() => _isSubmitting = false);
        AppToast.error(
          context,
          'Failed to submit ticket. Please try again.',
          title: 'Submission Error',
        );
      }
    } catch (e) {
      debugPrint('Error submitting ticket: $e');
      if (mounted) {
        AppToast.error(
          context,
          'Connection error. Please try again.',
          title: 'Network Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  IconData _getIconForFaq(int index) {
    switch (index % 5) {
      case 0:
        return Icons.local_shipping_outlined;
      case 1:
        return Icons.local_offer_outlined;
      case 2:
        return Icons.inventory_2_outlined;
      case 3:
        return Icons.credit_card_outlined;
      case 4:
        return Icons.location_on_outlined;
      default:
        return Icons.help_outline;
    }
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
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: const Color(0xFFF9F9F9),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: BounceButton(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E2022),
              size: 19,
            ),
          ),
          title: const Text(
            'Help & Support',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: BounceButton(
                  onTap: () {
                    final authRepo = CubePod.get<AuthRepository>();
                    if (!authRepo.isLoggedIn) {
                      _showLoginRequiredSheet('view and track your support tickets');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TicketStatusPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4EBDC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          size: 13,
                          color: Color(0xFF2E7D32),
                        ),
                        SizedBox(width: 5),
                        Text(
                          'My Tickets',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── 1. Hero Banner ──
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8F5E9), Color(0xFFF1F8F4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4EBDC), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 6,
                    bottom: -8,
                    top: -8,
                    child: Image.asset(
                      'assets/images/support_headset.png',
                      width: 105,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 18,
                      right: 105,
                      top: 18,
                      bottom: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'How can we help you?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2022),
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "We're here 24/7 to assist with any questions.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A6B62),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. Action Cards (Talk with Us & Call Us) ──
            Row(
              children: [
                Expanded(
                  child: BounceButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LiveChatPage()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFECEFF1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Talk with Us',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E2022),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Instant messaging',
                            style: TextStyle(
                              color: Color(0xFF717784),
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Start Conversation',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF2E7D32),
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BounceButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CallUsPage()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFECEFF1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: Color(0xFF1E2022),
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Call Us',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF1E2022),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Direct helpline',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Mon-Sat 9am-6pm',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF2E7D32),
                                size: 14,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 3. Frequently Asked Questions (3 Minimal Items) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2022),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '3 FAQs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // FAQs Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(_faqs.length, (index) {
                  final isExpanded = _expandedStates[index];
                  return Column(
                    children: [
                      BounceButton(
                        onTap: () {
                          setState(() {
                            _expandedStates[index] = !_expandedStates[index];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getIconForFaq(index),
                                  color: const Color(0xFF2E7D32),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _faqs[index]['question']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Color(0xFF1E2022),
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 50,
                            right: 16,
                            bottom: 13,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _faqs[index]['answer']!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      if (index < _faqs.length - 1)
                        Divider(
                          height: 1,
                          color: Colors.grey.shade100,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // ── 4. Send us a Message Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Send us a Message',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2022),
                  ),
                ),
                Text(
                  'Fast reply',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              'Leave a message and our support team will get back to you.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),

            // Guest user sign-in alert
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: CubePod.get<AuthRepository>().authStateNotifier,
              builder: (context, user, _) {
                final isLoggedIn = CubePod.get<AuthRepository>().isLoggedIn;
                if (isLoggedIn) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFFB45309), size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Login is required to track tickets.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF185B3A),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Message Input Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFECEFF1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _messageController,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E2022)),
                    decoration: InputDecoration(
                      hintText: 'Describe your issue or ask a question...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            BounceButton(
                              onTap: _showImagePickerModal,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _selectedAttachments.any((a) => a.isImage)
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.image_outlined,
                                  color: _selectedAttachments.any((a) => a.isImage)
                                      ? const Color(0xFF2E7D32)
                                      : Colors.grey.shade700,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            BounceButton(
                              onTap: _pickFile,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _selectedAttachments.any((a) => !a.isImage)
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.attach_file_outlined,
                                  color: _selectedAttachments.any((a) => !a.isImage)
                                      ? const Color(0xFF2E7D32)
                                      : Colors.grey.shade700,
                                  size: 19,
                                ),
                              ),
                            ),
                            if (_selectedAttachments.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_selectedAttachments.length} attached',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${_messageController.text.length}/1000',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Selected Attachments Preview Chips
                  if (_selectedAttachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedAttachments.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final att = _selectedAttachments[idx];
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 140,
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: att.isImage
                                            ? (att.data != null
                                                ? Image.memory(
                                                    att.data!,
                                                    width: 34,
                                                    height: 34,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Container(
                                                      width: 34,
                                                      height: 34,
                                                      color: const Color(0xFFE2E8F0),
                                                      child: const Icon(Icons.broken_image_rounded, size: 15, color: Color(0xFF64748B)),
                                                    ),
                                                  )
                                                : (att.path.isNotEmpty
                                                    ? Image.file(
                                                        File(att.path),
                                                        width: 34,
                                                        height: 34,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => Container(
                                                      width: 34,
                                                      height: 34,
                                                      color: const Color(0xFFE2E8F0),
                                                      child: const Icon(Icons.broken_image_rounded, size: 15, color: Color(0xFF64748B)),
                                                    ),
                                                      )
                                                    : Container(
                                                        width: 34,
                                                        height: 34,
                                                        color: const Color(0xFFE2E8F0),
                                                        child: const Icon(Icons.image_outlined, size: 15, color: Color(0xFF64748B)),
                                                      )))
                                            : Container(
                                                width: 34,
                                                height: 34,
                                                color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                                                child: const Icon(Icons.insert_drive_file_rounded, size: 17, color: Color(0xFF185B3A)),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              att.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              att.formattedSize,
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedAttachments.removeAt(idx);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE11D48),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                  // Send Ticket Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                    child: BounceButton(
                      onTap: _isSubmitting ? () {} : _submitTicket,
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B3D2F),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B3D2F).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSubmitting) ...[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sending...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Send Message',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.send_outlined,
                                color: Colors.white,
                                size: 15,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── 5. Bottom Guarantee Banner ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FBF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4EBDC), width: 1),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF2E7D32),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Satisfaction Guaranteed • Dedicated 24/7 Support',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        color: Color(0xFF1B3D2F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
