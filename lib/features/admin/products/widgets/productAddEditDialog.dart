import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:app/features/admin/products/providers/adminProductProviders.dart';

/// Builds a multipart file for image uploads.
http.MultipartFile buildImageMultipartFile(List<int> bytes, String filename) {
  final ext = filename.toLowerCase().split('.').last;
  final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
  return http.MultipartFile.fromBytes(
    'file',
    bytes,
    filename: filename,
    contentType: MediaType('image', subType),
  );
}

/// Self-contained Add/Edit Product dialog widget.
/// Extracted from ProductsPage to reduce its size.
class ProductAddEditDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;
  final String? initialCategoryId;
  final String? initialSubcategoryId;
  final List<dynamic> categories;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final bool isEdit;

  const ProductAddEditDialog({
    super.key,
    this.product,
    this.initialCategoryId,
    this.initialSubcategoryId,
    required this.categories,
    required this.onSave,
    required this.onDelete,
    required this.isEdit,
  });

  @override
  ConsumerState<ProductAddEditDialog> createState() => _ProductAddEditDialogState();
}

class _ProductAddEditDialogState extends ConsumerState<ProductAddEditDialog> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController origPriceCtrl;
  late final TextEditingController unitCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController imageCtrl;

  ProductAddEditUiState get _uiState => ref.watch(productAddEditUiProvider);
  String? get selectedCatId => _uiState.selectedCatId;
  String? get selectedSubId => _uiState.selectedSubId;
  bool get isTodaysChoice => _uiState.isTodaysChoice;
  bool get isSpecialDeal => _uiState.isSpecialDeal;
  bool get isPopular => _uiState.isPopular;
  bool get isActive => _uiState.isActive;
  bool get isUploading => _uiState.isUploading;
  bool get isSaving => _uiState.isSaving;

  @override
  void initState() {
    super.initState();
    final isEdit = widget.isEdit;
    final product = widget.product;

    titleCtrl = TextEditingController(text: isEdit ? product!['title'] : '');
    descCtrl = TextEditingController(text: isEdit ? (product!['description'] ?? '') : '');

    final pricePaise = isEdit ? (product!['price_paise'] as int? ?? 0) : 0;
    final origPricePaise = isEdit ? (product!['original_price_paise'] as int? ?? 0) : 0;

    priceCtrl = TextEditingController(
        text: isEdit && pricePaise > 0 ? (pricePaise / 100).round().toString() : '');
    origPriceCtrl = TextEditingController(
        text: isEdit && origPricePaise > 0 ? (origPricePaise / 100).round().toString() : '');

    unitCtrl = TextEditingController(text: isEdit ? (product!['unit'] ?? '1 kg') : '1 kg');
    stockCtrl = TextEditingController(
        text: isEdit ? (product!['stock_quantity']?.toString() ?? '50') : '50');
    imageCtrl = TextEditingController(
        text: isEdit ? (product!['image_url'] ?? '') : '');

    final initialCat = isEdit
        ? product!['category_id']?.toString()
        : (widget.initialCategoryId ??
            (widget.categories.isNotEmpty ? widget.categories.first['id']?.toString() : null));

    final initialSub = isEdit ? product!['subcategory_id']?.toString() : widget.initialSubcategoryId;
    final initialTodaysChoice = isEdit ? product!['is_todays_choice'] == true : false;
    final initialSpecialDeal = isEdit ? product!['is_special_deal'] == true : false;
    final initialPopular = isEdit ? product!['is_popular'] == true : false;
    final initialActive = isEdit ? product!['is_active'] != false : true;

    Future.microtask(() {
      ref.read(productAddEditUiProvider.notifier).init(
            catId: initialCat,
            subId: initialSub,
            todaysChoice: initialTodaysChoice,
            specialDeal: initialSpecialDeal,
            popular: initialPopular,
            active: initialActive,
          );
    });
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    origPriceCtrl.dispose();
    unitCtrl.dispose();
    stockCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  List<dynamic> get dialogSubcategories {
    if (selectedCatId == null) return [];
    final cat = widget.categories.firstWhere(
      (c) => c['id']?.toString() == selectedCatId,
      orElse: () => null,
    );
    if (cat != null && cat['subcategories'] is List) {
      return cat['subcategories'];
    }
    return [];
  }

  Future<void> handleSave() async {
    if (titleCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and Price are required')),
      );
      return;
    }

    ref.read(productAddEditUiProvider.notifier).setSaving(true);
    try {
      final pPaise = ((double.tryParse(priceCtrl.text) ?? 0) * 100).round();
      final origPPaise = origPriceCtrl.text.isNotEmpty
          ? ((double.tryParse(origPriceCtrl.text) ?? 0) * 100).round()
          : null;

      final payload = {
        if (widget.isEdit) 'id': widget.product!['id'],
        'title': titleCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'price_paise': pPaise,
        'original_price_paise': origPPaise,
        'unit': unitCtrl.text.trim(),
        'stock_quantity': int.tryParse(stockCtrl.text) ?? 50,
        'category_id': selectedCatId,
        'subcategory_id': selectedSubId,
        'image_url': imageCtrl.text.trim(),
        'is_todays_choice': isTodaysChoice,
        'is_special_deal': isSpecialDeal,
        'is_popular': isPopular,
        'is_active': isActive,
      };

      final headers = {
        ...ref.read(authRepositoryProvider).authHeaders,
        'Content-Type': 'application/json',
      };
      final url = Uri.parse('${AppConfig.apiUrl}/admin/products');
      final messenger = ScaffoldMessenger.of(context);

      http.Response res;
      if (widget.isEdit) {
        res = await http.patch(
          url,
          headers: headers,
          body: jsonEncode(payload),
        );
        if (res.statusCode == 404 || res.statusCode == 405) {
          res = await http.put(
            url,
            headers: headers,
            body: jsonEncode(payload),
          );
        }
      } else {
        res = await http.post(
          url,
          headers: headers,
          body: jsonEncode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
        }
        widget.onSave();
        messenger.showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Product updated!' : 'Product added!'),
            backgroundColor: const Color(0xFF185B3A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save: ${res.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error saving product: $e');
    } finally {
      if (mounted) ref.read(productAddEditUiProvider.notifier).setSaving(false);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      ref.read(productAddEditUiProvider.notifier).setUploading(true);
      try {
        final bytes = await picked.readAsBytes();
        final uri = Uri.parse('${AppConfig.apiUrl}/admin/products/upload');
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(ref.read(authRepositoryProvider).multipartAuthHeaders);
        request.files.add(buildImageMultipartFile(bytes, picked.name));
        final streamedRes = await request.send();
        final res = await http.Response.fromStream(streamedRes);
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
          if (uploadedUrl != null) {
            imageCtrl.text = uploadedUrl.toString();
          }
        } else {
          String errTxt = 'Upload failed (${res.statusCode})';
          try {
            final d = jsonDecode(res.body);
            errTxt = d['error'] ?? d['message'] ?? errTxt;
          } catch (_) {}
          if (res.statusCode == 401) {
            errTxt = 'Session expired. Please log in again.';
          }
          if (mounted) {
            AppToast.error(context, errTxt);
          }
        }
      } catch (e) {
        debugPrint('Error uploading product image: $e');
        if (mounted) {
          AppToast.error(context, 'Image upload failed: $e');
        }
      } finally {
        if (mounted) ref.read(productAddEditUiProvider.notifier).setUploading(false);
      }
    }
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEdit ? 'Product Details & Edit' : 'Add New Product',
                      style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      widget.isEdit ? 'View & edit details, prices & category' : 'Fill details to add to catalog',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.isEdit) ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                        tooltip: 'Delete Product',
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('Product Title *', titleCtrl, 'e.g. Royal Gala Apples'),
                  const SizedBox(height: 14),
                  _buildField('Description', descCtrl, 'e.g. Crisp, sweet organic farm-picked apples', maxLines: 2),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildField('Price (₹) *', priceCtrl, '120', isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Original Price (₹)', origPriceCtrl, '160', isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildField('Unit (Weight/Qty)', unitCtrl, '1 kg / 500 g / 1 dozen')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Stock Quantity', stockCtrl, '50', isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  Text('Category *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedCatId,
                        hint: Text('Select Category', style: GoogleFonts.outfit(fontSize: 13)),
                        items: widget.categories.map<DropdownMenuItem<String>>((cat) {
                          final id = cat['id']?.toString();
                          final name = (cat['name'] ?? cat['label'] ?? 'Category').toString();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          ref.read(productAddEditUiProvider.notifier).selectCategory(val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subcategory Dropdown
                  Text('Subcategory', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: dialogSubcategories.isEmpty ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedSubId,
                        hint: Text(
                          dialogSubcategories.isEmpty
                              ? 'Select a category first'
                              : 'Select Subcategory (Optional)',
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                        ),
                        items: dialogSubcategories.map<DropdownMenuItem<String>>((sub) {
                          final id = sub['id']?.toString();
                          final name = (sub['name'] ?? 'Subcategory').toString();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5)),
                          );
                        }).toList(),
                        onChanged: dialogSubcategories.isEmpty
                            ? null
                            : (val) => ref.read(productAddEditUiProvider.notifier).selectSubcategory(val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image Upload & Preview
                  Text('Product Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: imageCtrl,
                    builder: (context, val, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: imageCtrl,
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Image URL or pick an image...',
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: isUploading ? null : pickImage,
                                icon: isUploading
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.upload_file, size: 16, color: Colors.white),
                                label: Text('Pick', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          if (val.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: SkeletonImage(
                                  imageUrl: val.text.trim(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Toggle Badges
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF185B3A),
                    title: Text("Active in Catalog", style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text("Display and allow purchase in the store", style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: isActive,
                    onChanged: (val) => ref.read(productAddEditUiProvider.notifier).setActive(val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF185B3A),
                    title: Text("Today's Choice", style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text("Feature on Home Screen Today's Choice section", style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: isTodaysChoice,
                    onChanged: (val) => ref.read(productAddEditUiProvider.notifier).setTodaysChoice(val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF185B3A),
                    title: Text('Special Deal', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('Showcase in Deals & Super Savers', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: isSpecialDeal,
                    onChanged: (val) => ref.read(productAddEditUiProvider.notifier).setSpecialDeal(val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: const Color(0xFF185B3A),
                    title: Text('Popular Item', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('Display in trending & popular grocery list', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                    value: isPopular,
                    onChanged: (val) => ref.read(productAddEditUiProvider.notifier).setPopular(val),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (widget.isEdit) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                backgroundColor: const Color(0xFFFEF2F2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                              label: Text(
                                'Delete',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      widget.onDelete();
                                    },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF185B3A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: isSaving ? null : handleSave,
                              child: isSaving
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      'Save Changes',
                                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isSaving ? null : handleSave,
                        child: isSaving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Add to Catalog',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
