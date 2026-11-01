import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/services/cacheService.dart';
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:app/features/admin/products/widgets/productColorPicker.dart';
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

/// Self-contained Add Category dialog widget.
/// Extracted from ProductsPage to reduce its size.
class AddCategoryDialog extends ConsumerStatefulWidget {
  final List<dynamic> categories;
  final VoidCallback onCategoryCreated;

  const AddCategoryDialog({super.key, required this.categories, required this.onCategoryCreated});

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final nameCtrl = TextEditingController();
  final imageCtrl = TextEditingController();

  AddCategoryUiState get _uiState => ref.watch(addCategoryUiProvider);
  Uint8List? get pickedImageBytes => _uiState.pickedImageBytes;
  String? get pickedImageName => _uiState.pickedImageName;
  String? get selectedColor => _uiState.selectedColor;
  bool get isSaving => _uiState.isSaving;

  final presetColors = [
    {'name': 'Emerald', 'hex': '#185B3A'},
    {'name': 'Forest', 'hex': '#10B981'},
    {'name': 'Blue', 'hex': '#3B82F6'},
    {'name': 'Amber', 'hex': '#F59E0B'},
    {'name': 'Rose', 'hex': '#EF4444'},
    {'name': 'Purple', 'hex': '#8B5CF6'},
  ];

  @override
  void dispose() {
    nameCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    if (pickedImageBytes == null) return;
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/admin/categories/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(ref.read(authRepositoryProvider).multipartAuthHeaders);
      request.fields['type'] = 'category';
      request.fields['name'] = nameCtrl.text.trim();
      request.files.add(buildImageMultipartFile(pickedImageBytes!, pickedImageName ?? 'category.jpg'));
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
        if (uploadedUrl != null) {
          imageCtrl.text = uploadedUrl.toString();
          ref.read(addCategoryUiProvider.notifier).setImage(bytes: null, name: null);
          return;
        }
      }
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
    } catch (e) {
      debugPrint('Error uploading category image: $e');
      if (mounted) {
        AppToast.error(context, 'Failed to upload category image: $e');
      }
    }
  }

  Future<void> _saveCategory() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.warning(context, 'Please enter category name');
      return;
    }
    if (pickedImageBytes == null && imageCtrl.text.trim().isEmpty) {
      AppToast.warning(context, 'Please select or upload a category image');
      return;
    }

    ref.read(addCategoryUiProvider.notifier).setSaving(true);
    try {
      String? finalImageUrl;

      if (pickedImageBytes != null) {
        await _uploadImage();
        finalImageUrl = imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null;
      } else if (imageCtrl.text.trim().isNotEmpty) {
        finalImageUrl = imageCtrl.text.trim();
      }

      if (pickedImageBytes != null && (finalImageUrl == null || finalImageUrl.isEmpty)) {
        if (mounted) {
          AppToast.error(context, 'Failed to upload category image. Please try again.');
        }
        return;
      }

      final payload = {
        'name': name,
        'label': name,
        'color_hex': selectedColor,
        'color': selectedColor,
        'image_url': finalImageUrl,
        'image': finalImageUrl,
      };
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/admin/categories'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) Navigator.pop(context);
        widget.onCategoryCreated();

        try {
          final currentCache = CacheService.get<List>('categories') ?? [];
          final dynamic resJson = jsonDecode(res.body);
          final createdCat = resJson is Map ? (resJson['data'] ?? resJson['category'] ?? payload) : payload;
          CacheService.set('categories', [...currentCache, createdCat]);
        } catch (_) {}

        if (mounted) {
          AppToast.success(context, 'Category created successfully!');
        }
      } else {
        String errorMsg = 'Failed to create category';
        try {
          final errData = jsonDecode(res.body);
          errorMsg = errData['error'] ?? errData['message'] ?? errorMsg;
        } catch (_) {}

        if (errorMsg.contains('categories_slug_key') ||
            errorMsg.contains('duplicate key') ||
            errorMsg.contains('unique constraint')) {
          errorMsg = 'A category named "$name" already exists. Please use a different name.';
        }

        if (mounted) {
          AppToast.error(context, errorMsg);
        }
      }
    } catch (e) {
      debugPrint('Error creating category: $e');
      if (mounted) {
        AppToast.error(context, 'Error creating category: $e');
      }
    } finally {
      if (mounted) ref.read(addCategoryUiProvider.notifier).setSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Category', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text('Category Name *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. Spices & Masalas',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            Text('Category Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: imageCtrl,
                    onChanged: (_) {
                      ref.read(addCategoryUiProvider.notifier).setImage(bytes: null, name: null);
                    },
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Image URL or pick from device...',
                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
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
                  onPressed: isSaving ? null : () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      ref.read(addCategoryUiProvider.notifier).setImage(bytes: bytes, name: picked.name);
                      imageCtrl.text = picked.name;
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                  label: Text('Upload', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            if (pickedImageBytes != null || imageCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: pickedImageBytes != null
                          ? Image.memory(pickedImageBytes!, fit: BoxFit.cover)
                          : SkeletonImage(imageUrl: imageCtrl.text.trim(), fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        ref.read(addCategoryUiProvider.notifier).setImage(bytes: null, name: null);
                        imageCtrl.clear();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Theme Color', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RgbColorPickerDialog(
                        initialHex: selectedColor,
                        onSelected: (newHex) {
                          ref.read(addCategoryUiProvider.notifier).setColor(newHex);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.colorize_rounded, size: 14, color: Color(0xFF185B3A)),
                  label: Text('RGB Picker', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A))),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => ref.read(addCategoryUiProvider.notifier).setColor(null),
                  child: Tooltip(
                    message: 'No Color (Null)',
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == null ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                          width: selectedColor == null ? 2.5 : 1.5,
                        ),
                        boxShadow: selectedColor == null
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Center(
                        child: selectedColor == null
                            ? const Icon(Icons.check, size: 18, color: Color(0xFF0F172A))
                            : const Icon(Icons.block_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                ...presetColors.map((col) {
                  final hex = col['hex']!;
                  final isSel = selectedColor != null && selectedColor!.toUpperCase() == hex.toUpperCase();
                  final c = RgbColorPickerDialog.parseHexColor(hex);
                  return GestureDetector(
                    onTap: () => ref.read(addCategoryUiProvider.notifier).setColor(hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? Colors.black87 : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSel
                            ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                    ),
                  );
                }),
                if (selectedColor != null && !presetColors.any((col) => col['hex']!.toUpperCase() == selectedColor!.toUpperCase())) ...[
                  Builder(builder: (_) {
                    final c = RgbColorPickerDialog.parseHexColor(selectedColor!);
                    return Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black87, width: 2.5),
                        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.check, size: 18, color: Colors.white),
                    );
                  }),
                ],
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => RgbColorPickerDialog(
                        initialHex: selectedColor,
                        onSelected: (newHex) {
                          ref.read(addCategoryUiProvider.notifier).setColor(newHex);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFF8800),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (selectedColor == null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      ),
                      child: const Icon(Icons.block_rounded, size: 20, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Color Selected (Null)',
                            style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Category will display with default neutral styling',
                            style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF185B3A),
                        side: const BorderSide(color: Color(0xFF185B3A)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => RgbColorPickerDialog(
                            initialHex: null,
                            onSelected: (newHex) {
                              ref.read(addCategoryUiProvider.notifier).setColor(newHex);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.palette_rounded, size: 14),
                      label: Text('Pick Color', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: RgbColorPickerDialog.parseHexColor(selectedColor!),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black12, width: 1),
                            boxShadow: [
                              BoxShadow(color: RgbColorPickerDialog.parseHexColor(selectedColor!).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedColor!.toUpperCase(),
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                () {
                                  final c = RgbColorPickerDialog.parseHexColor(selectedColor!);
                                  return 'rgb(${RgbColorPickerDialog.colorR(c)}, ${RgbColorPickerDialog.colorG(c)}, ${RgbColorPickerDialog.colorB(c)})';
                                }(),
                                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF185B3A),
                            side: const BorderSide(color: Color(0xFF185B3A)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => RgbColorPickerDialog(
                                initialHex: selectedColor,
                                onSelected: (newHex) {
                                  ref.read(addCategoryUiProvider.notifier).setColor(newHex);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.tune_rounded, size: 14),
                          label: Text('RGB Picker', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isSaving ? null : _saveCategory,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Create Category', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-contained Add Subcategory dialog widget.
/// Extracted from ProductsPage to reduce its size.
class AddSubcategoryDialog extends ConsumerStatefulWidget {
  final List<dynamic> categories;
  final String? initialCategoryId;
  final VoidCallback onSubcategoryCreated;

  const AddSubcategoryDialog({
    super.key,
    required this.categories,
    this.initialCategoryId,
    required this.onSubcategoryCreated,
  });

  @override
  ConsumerState<AddSubcategoryDialog> createState() => _AddSubcategoryDialogState();
}

class _AddSubcategoryDialogState extends ConsumerState<AddSubcategoryDialog> {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imageCtrl = TextEditingController();

  AddSubcategoryUiState get _uiState => ref.watch(addSubcategoryUiProvider);
  String? get selectedParentId => _uiState.selectedParentId;
  bool get isSaving => _uiState.isSaving;
  bool get isUploading => _uiState.isUploading;

  @override
  void initState() {
    super.initState();
    final parentId = widget.initialCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first['id']?.toString() : null);
    Future.microtask(() {
      ref.read(addSubcategoryUiProvider.notifier).init(parentId);
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    if (nameCtrl.text.trim().isEmpty) return;
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/admin/categories/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(ref.read(authRepositoryProvider).multipartAuthHeaders);
      request.fields['type'] = 'subcategory';
      request.fields['name'] = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'subcategory';
      final bytes = await pickedImage!.readAsBytes();
      request.files.add(buildImageMultipartFile(bytes, pickedImage!.name));
      final streamedRes = await request.send();
      final res = await http.Response.fromStream(streamedRes);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
        if (uploadedUrl != null) {
          imageCtrl.text = uploadedUrl.toString();
          return;
        }
      }
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
    } catch (e) {
      debugPrint('Error uploading subcategory image: $e');
      if (mounted) {
        AppToast.error(context, 'Upload failed: $e');
      }
    } finally {
      if (mounted) ref.read(addSubcategoryUiProvider.notifier).setUploading(false);
    }
  }

  XFile? pickedImage;

  Future<void> _saveSubcategory() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.warning(context, 'Please enter subcategory name');
      return;
    }
    if (selectedParentId == null) {
      AppToast.warning(context, 'Please select a parent category');
      return;
    }

    ref.read(addSubcategoryUiProvider.notifier).setSaving(true);
    try {
      final payload = {
        'category_id': selectedParentId,
        'name': name,
        'image_url': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
        'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
      };
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/admin/subcategories'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) Navigator.pop(context);
        widget.onSubcategoryCreated();
        if (mounted) {
          AppToast.success(context, 'Subcategory created successfully!');
        }
      } else {
        String errorMsg = 'Failed to create subcategory';
        try {
          final errData = jsonDecode(res.body);
          errorMsg = errData['error'] ?? errData['message'] ?? errorMsg;
        } catch (_) {}

        if (errorMsg.contains('duplicate key') || errorMsg.contains('unique constraint')) {
          errorMsg = 'A subcategory named "$name" already exists.';
        }

        if (mounted) {
          AppToast.error(context, errorMsg);
        }
      }
    } catch (e) {
      debugPrint('Error creating subcategory: $e');
      if (mounted) {
        AppToast.error(context, 'Error creating subcategory: $e');
      }
    } finally {
      if (mounted) ref.read(addSubcategoryUiProvider.notifier).setSaving(false);
    }
  }

  List<dynamic> get dialogSubcategories {
    if (selectedParentId == null) return [];
    final cat = widget.categories.firstWhere(
      (c) => c['id']?.toString() == selectedParentId,
      orElse: () => null,
    );
    if (cat != null && cat['subcategories'] is List) {
      return cat['subcategories'];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('New Subcategory', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text('Parent Category *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
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
                  value: selectedParentId,
                  items: widget.categories.map<DropdownMenuItem<String>>((cat) {
                    final id = cat['id']?.toString();
                    final name = (cat['name'] ?? cat['label'] ?? 'Category').toString();
                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) => ref.read(addSubcategoryUiProvider.notifier).setParentId(val),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Subcategory Name *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. Whole Spices, Green Apples',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            Text('Subcategory Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: imageCtrl,
              builder: (context, imgVal, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: imageCtrl,
                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Image URL or pick image...',
                              hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: isUploading ? null : () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (picked != null) {
                              pickedImage = picked;
                              ref.read(addSubcategoryUiProvider.notifier).setUploading(true);
                              await _uploadImage();
                            }
                          },
                          icon: isUploading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                          label: Text(isUploading ? 'Uploading...' : 'Upload', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (imgVal.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: SkeletonImage(imageUrl: imgVal.text.trim(), fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => imageCtrl.clear(),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text('Description (Optional)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: descCtrl,
              style: GoogleFonts.outfit(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Brief description of subcategory items',
                hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: isSaving ? null : _saveSubcategory,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Create Subcategory', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action option tile used in the "Create New" options sheet.
Widget buildActionOptionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color iconColor,
  required Color bgColor,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
        ],
      ),
    ),
  );
}
