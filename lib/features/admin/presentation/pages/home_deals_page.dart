import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:app/core/widgets/skeleton_image.dart';

class HomeDealsPage extends StatefulWidget {
  const HomeDealsPage({super.key});

  @override
  State<HomeDealsPage> createState() => _HomeDealsPageState();
}

class _HomeDealsPageState extends State<HomeDealsPage> {
  bool _isLoading = true;
  List<dynamic> _deals = [];
  List<dynamic> _allProducts = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDeals(),
      _fetchAllProducts(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchDeals() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/home-deals'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _deals = data['home_deals'] ?? [];
      }
    } catch (e) {
      debugPrint('[HomeDealsPage] Error fetching deals: $e');
    }
  }

  Future<void> _fetchAllProducts() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?limit=100'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _allProducts = data['products'] ?? [];
      }
    } catch (e) {
      debugPrint('[HomeDealsPage] Error fetching products: $e');
    }
  }

  Future<void> _deleteDeal(dynamic id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Deal Banner?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this campaign banner?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/home-deals?id=$id'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      _fetchDeals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deal banner deleted successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting deal: $e');
    }
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) return Color(int.parse('0xFF$clean'));
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  void _showDealDialog({Map<String, dynamic>? deal}) {
    final isEdit = deal != null;
    final titleCtrl = TextEditingController(text: isEdit ? deal['title'] : '');
    final subtitleCtrl = TextEditingController(text: isEdit ? (deal['subtitle'] ?? '') : '');
    final badgeCtrl = TextEditingController(text: isEdit ? (deal['badge_text'] ?? '⚡ FLASH SALE') : '⚡ FLASH SALE');
    final buttonTextCtrl = TextEditingController(text: isEdit ? (deal['button_text'] ?? 'Shop Now') : 'Shop Now');
    final discountCtrl = TextEditingController(text: isEdit ? (deal['discount_percent']?.toString() ?? '25') : '25');
    final imageCtrl = TextEditingController(text: isEdit ? (deal['image_url'] ?? '') : '');
    final bgColorCtrl = TextEditingController(text: isEdit ? (deal['bg_color'] ?? '#E8F5EE') : '#E8F5EE');
    final btnColorCtrl = TextEditingController(text: isEdit ? (deal['button_color'] ?? '#185B3A') : '#185B3A');

    List<String> selectedProductIds = [];
    if (isEdit && deal['product_ids'] is List) {
      selectedProductIds = List<String>.from(deal['product_ids'].map((e) => e.toString()));
    }

    bool isUploading = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Campaign Banner' : 'New Campaign Banner',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Form Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Banner Live Preview ──
                          Text(
                            'LIVE PREVIEW',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: _parseHex(bgColorCtrl.text, const Color(0xFFE8F5EE)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (badgeCtrl.text.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _parseHex(btnColorCtrl.text, const Color(0xFF185B3A)).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              badgeCtrl.text,
                                              style: GoogleFonts.outfit(
                                                color: _parseHex(btnColorCtrl.text, const Color(0xFF185B3A)),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          titleCtrl.text.isEmpty ? 'Banner Title' : titleCtrl.text,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          subtitleCtrl.text.isEmpty ? 'Subtitle goes here' : subtitleCtrl.text,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (imageCtrl.text.isNotEmpty)
                                  Expanded(
                                    flex: 9,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      child: SkeletonImage(
                                        imageUrl: imageCtrl.text,
                                        fit: BoxFit.cover,
                                        height: 120,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Fields ──
                          _buildTextField('Title *', titleCtrl, 'e.g. Farm Fresh Mega Deal', onChanged: (_) => setDialogState(() {})),
                          const SizedBox(height: 14),
                          _buildTextField('Subtitle', subtitleCtrl, 'e.g. Grab fresh organic veggies & farm fruits', onChanged: (_) => setDialogState(() {})),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Badge Text', badgeCtrl, 'e.g. ⚡ FLASH SALE', onChanged: (_) => setDialogState(() {}))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField('Discount %', discountCtrl, 'e.g. 25', isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Image URL + Upload Button
                          Text('Banner Image URL', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: imageCtrl,
                                  onChanged: (_) => setDialogState(() {}),
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'https://images.unsplash.com/...',
                                    hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF185B3A),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: isUploading ? null : () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                  if (picked != null) {
                                    setDialogState(() => isUploading = true);
                                    try {
                                      final bytes = await picked.readAsBytes();
                                      final uri = Uri.parse('${AppConfig.apiUrl}/admin/home-deals/upload');
                                      final request = http.MultipartRequest('POST', uri);
                                      request.headers.addAll(CubePod.get<AuthRepository>().authHeaders);
                                      final ext = picked.name.toLowerCase().split('.').last;
                                      final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
                                      request.files.add(http.MultipartFile.fromBytes(
                                        'file',
                                        bytes,
                                        filename: picked.name,
                                        contentType: MediaType('image', subType),
                                      ));
                                      final streamedRes = await request.send();
                                      final res = await http.Response.fromStream(streamedRes);
                                      if (res.statusCode == 200) {
                                        final data = jsonDecode(res.body);
                                        if (data['image_url'] != null) {
                                          imageCtrl.text = data['image_url'];
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error uploading image: $e');
                                    } finally {
                                      setDialogState(() => isUploading = false);
                                    }
                                  }
                                },
                                icon: isUploading
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.upload_file, size: 16, color: Colors.white),
                                label: Text('Upload', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Color Hex Inputs
                          Row(
                            children: [
                              Expanded(child: _buildTextField('Bg Color (Hex)', bgColorCtrl, '#E8F5EE', onChanged: (_) => setDialogState(() {}))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildTextField('Theme/Btn Color', btnColorCtrl, '#185B3A', onChanged: (_) => setDialogState(() {}))),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── EXPLICIT PRODUCT BINDING SECTION ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
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
                                        const Icon(Icons.link_rounded, color: Color(0xFF185B3A), size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Bound Products (${selectedProductIds.length})',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _openProductPickerModal(
                                        context,
                                        selectedProductIds,
                                        (updated) => setDialogState(() => selectedProductIds = updated),
                                      ),
                                      icon: const Icon(Icons.add_shopping_cart, size: 16, color: Color(0xFF185B3A)),
                                      label: Text(
                                        'Select Products',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF185B3A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (selectedProductIds.isEmpty)
                                  Text(
                                    'No products bound yet. Tap "Select Products" to choose exact products for this banner.',
                                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: selectedProductIds.map((pId) {
                                      final matched = _allProducts.firstWhere(
                                        (p) => p['id'] == pId,
                                        orElse: () => {'title': 'Product ($pId)'},
                                      );
                                      final title = matched['title'] ?? 'Product';
                                      return Chip(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        label: Text(
                                          title,
                                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                                        ),
                                        deleteIcon: const Icon(Icons.close, size: 14),
                                        onDeleted: () {
                                          setDialogState(() {
                                            selectedProductIds.remove(pId);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF185B3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isSaving ? null : () async {
                                if (titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Banner Title is required')),
                                  );
                                  return;
                                }

                                setDialogState(() => isSaving = true);
                                try {
                                  final payload = {
                                    if (isEdit) 'id': deal['id'],
                                    'title': titleCtrl.text.trim(),
                                    'subtitle': subtitleCtrl.text.trim(),
                                    'badge_text': badgeCtrl.text.trim(),
                                    'button_text': buttonTextCtrl.text.trim(),
                                    'discount_percent': double.tryParse(discountCtrl.text) ?? 25.0,
                                    'image_url': imageCtrl.text.trim(),
                                    'bg_color': bgColorCtrl.text.trim(),
                                    'button_color': btnColorCtrl.text.trim(),
                                    'target_type': 'products',
                                    'product_ids': selectedProductIds,
                                    'is_active': true,
                                  };

                                  final res = isEdit
                                      ? await http.put(
                                          Uri.parse('${AppConfig.apiUrl}/admin/home-deals'),
                                          headers: {
                                            ...CubePod.get<AuthRepository>().authHeaders,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode(payload),
                                        )
                                      : await http.post(
                                          Uri.parse('${AppConfig.apiUrl}/admin/home-deals'),
                                          headers: {
                                            ...CubePod.get<AuthRepository>().authHeaders,
                                            'Content-Type': 'application/json',
                                          },
                                          body: jsonEncode(payload),
                                        );

                                  if (!mounted || !ctx.mounted) return;
                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    Navigator.pop(ctx);
                                    _fetchDeals();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(isEdit ? 'Banner updated!' : 'Banner created!')),
                                    );
                                  } else {
                                    final errData = jsonDecode(res.body);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(errData['error'] ?? 'Failed to save deal')),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error saving deal: $e');
                                } finally {
                                  setDialogState(() => isSaving = false);
                                }
                              },
                              child: isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      isEdit ? 'Save Changes' : 'Create Banner',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
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

  void _openProductPickerModal(
    BuildContext parentContext,
    List<String> currentSelected,
    Function(List<String>) onSave,
  ) {
    List<String> tempSelected = List<String>.from(currentSelected);
    String searchFilter = '';
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = _allProducts.where((p) {
              final title = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
              return title.contains(searchFilter.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Bound Products',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${tempSelected.length} selected',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF185B3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (val) => setPickerState(() => searchFilter = val),
                      style: GoogleFonts.outfit(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final id = p['id'].toString();
                        final title = p['title'] ?? p['name'] ?? 'Product';
                        final price = p['price'] ?? (p['price_paise'] != null ? (p['price_paise'] / 100).toStringAsFixed(0) : '0');
                        final image = p['image_url'] ?? p['image'] ?? '';
                        final isSelected = tempSelected.contains(id);

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: const Color(0xFF185B3A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            '₹$price  •  ${p['unit'] ?? '1 pc'}',
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          onChanged: (val) {
                            setPickerState(() {
                              if (val == true) {
                                tempSelected.add(id);
                              } else {
                                tempSelected.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          onSave(tempSelected);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Done (${tempSelected.length} Products)',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: onChanged,
          style: GoogleFonts.outfit(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  List<dynamic> get _filteredDeals {
    var list = List<dynamic>.from(_deals);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final subtitle = (d['subtitle'] ?? '').toString().toLowerCase();
        final badge = (d['badge_text'] ?? '').toString().toLowerCase();
        return title.contains(q) || subtitle.contains(q) || badge.contains(q);
      }).toList();
    }
    if (_selectedFilter == 'With Products') {
      list = list.where((d) {
        final ids = d['product_ids'];
        return ids is List && ids.isNotEmpty;
      }).toList();
    } else if (_selectedFilter == 'No Products') {
      list = list.where((d) {
        final ids = d['product_ids'];
        return ids is! List || ids.isEmpty;
      }).toList();
    }
    return list;
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedFilter = label);
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
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDeals;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        titleSpacing: Navigator.canPop(context) ? 0 : 16,
        title: Row(
          children: [
            Text(
              'Campaign Banners',
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
                '${_deals.length}',
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
      floatingActionButton: (_deals.isEmpty && _searchQuery.isEmpty && _selectedFilter == 'All')
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF185B3A),
              elevation: 3,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                'New Banner',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () => _showDealDialog(),
            ),
      body: Column(
        children: [
          // Search & Filter Header Container
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
                            hintText: 'Search banners by title, subtitle, badge...',
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

                // Quick Filter Chips
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('With Products'),
                      _buildFilterChip('No Products'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Banner list or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                      ? const Color(0xFFF8FAFC)
                                      : const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                      ? Icons.search_off_rounded
                                      : Icons.campaign_rounded,
                                  size: 42,
                                  color: (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                    ? 'No Matching Banners'
                                    : 'No Campaign Banners',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                    ? 'Try checking for typos or reset your search and filter criteria.'
                                    : 'Create promotional banners with custom colors and discounts to feature on the customer home screen.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_searchQuery.isNotEmpty || _selectedFilter != 'All')
                                TextButton.icon(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedFilter = 'All';
                                    });
                                  },
                                  icon: const Icon(Icons.restart_alt_rounded, size: 17, color: Color(0xFF185B3A)),
                                  label: Text(
                                    'Reset Filters',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF185B3A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton.icon(
                                  onPressed: () => _showDealDialog(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF185B3A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(
                                    'Create First Banner',
                                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF185B3A),
                        onRefresh: _fetchData,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final deal = filtered[index];
                            final title = deal['title'] ?? 'Deal';
                            final subtitle = deal['subtitle'] ?? '';
                            final badge = deal['badge_text'] ?? '⚡ SALE';
                            final image = deal['image_url'] ?? '';
                            final boundCount = (deal['product_ids'] is List) ? (deal['product_ids'] as List).length : 0;
                            final bgColor = _parseHex(deal['bg_color'], const Color(0xFFE8F5EE));
                            final btnColor = _parseHex(deal['button_color'], const Color(0xFF185B3A));
                            final discount = deal['discount_percent']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Banner Card Preview
                                  Container(
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 11,
                                          child: Padding(
                                            padding: const EdgeInsets.all(14.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: btnColor.withValues(alpha: 0.14),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        badge,
                                                        style: GoogleFonts.outfit(
                                                          color: btnColor,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ),
                                                    if (discount.isNotEmpty && discount != '0') ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          '$discount% OFF',
                                                          style: GoogleFonts.outfit(
                                                            color: const Color(0xFFDC2626),
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  title,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (subtitle.isNotEmpty)
                                                  Text(
                                                    subtitle,
                                                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (image.isNotEmpty)
                                          Expanded(
                                            flex: 9,
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(18),
                                              ),
                                              child: SkeletonImage(imageUrl: image, fit: BoxFit.cover, height: 110),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Footer Actions & Product count
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: boundCount > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: boundCount > 0 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.link_rounded,
                                                size: 14,
                                                color: boundCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$boundCount Products Bound',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: boundCount > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit Banner',
                                              icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF475569)),
                                              onPressed: () => _showDealDialog(deal: deal),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete Banner',
                                              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFE11D48)),
                                              onPressed: () => _deleteDeal(deal['id']),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
typedef ManageHomeDealsPage = HomeDealsPage;
