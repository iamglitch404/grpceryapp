import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:app/core/services/cache_service.dart';
import 'package:app/core/widgets/toast.dart';

http.MultipartFile _buildImageMultipartFile(List<int> bytes, String filename) {
  final ext = filename.toLowerCase().split('.').last;
  final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
  return http.MultipartFile.fromBytes(
    'file',
    bytes,
    filename: filename,
    contentType: MediaType('image', subType),
  );
}

class CategoriesPage extends StatefulWidget {
  final bool autoOpenAddDialog;
  const CategoriesPage({super.key, this.autoOpenAddDialog = false});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  bool _isLoading = true;
  List<dynamic> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.autoOpenAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCategoryDialog();
      });
    }
  }

  Future<void> _fetchCategories() async {
    final cached = CacheService.get<List>('categories');
    if (cached != null && cached.isNotEmpty && _categories.isEmpty && mounted) {
      setState(() {
        _categories = cached;
        _isLoading = false;
      });
    } else if (_categories.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/categories'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded is List ? decoded : (decoded['data'] is List ? decoded['data'] : []);
        if (mounted) {
          setState(() {
            _categories = list;
            _isLoading = false;
          });
        }
        CacheService.set('categories', list);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _deleteCategory(dynamic id) async {
    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/categories?id=$id'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        if (mounted) AppToast.success(context, 'Category deleted successfully');
        _fetchCategories();
      } else {
        if (mounted) AppToast.error(context, 'Failed to delete category');
      }
    } catch (e) {
      debugPrint('Error deleting category: $e');
      if (mounted) AppToast.error(context, 'Error deleting category: $e');
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF);
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  void _showCategoryDialog({Map<String, dynamic>? category}) {
    final isEdit = category != null;
    final labelCtrl = TextEditingController(text: isEdit ? category['label'] : '');
    final colorCtrl = TextEditingController(text: isEdit ? category['color'] : '#FFFFFF');
    String? currentImageUrl = isEdit && category['image'] != null && category['image'].toString().trim().isNotEmpty
        ? category['image'].toString().trim()
        : null;
    if (currentImageUrl != null && currentImageUrl.contains('unsplash.com')) {
      currentImageUrl = null;
    }
    Uint8List? selectedImageBytes;
    bool isUploading = false;
    bool showImageError = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<void> pickImage() async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                final bytes = await image.readAsBytes();
                setStateDialog(() {
                  selectedImageBytes = bytes;
                  showImageError = false;
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        isEdit ? 'Edit Category' : 'Add New Category',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Category Name (Label)'),
                    _buildTextField(labelCtrl),
                    const SizedBox(height: 16),
                    _buildLabel('Category Image'),
                    InkWell(
                      onTap: pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: showImageError ? Colors.red : Colors.grey.shade300,
                            width: showImageError ? 1.5 : 1.0,
                          ),
                        ),
                        child: selectedImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                              )
                            : currentImageUrl != null && currentImageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(currentImageUrl, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload,
                                        color: showImageError ? Colors.red : Colors.grey,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        showImageError ? 'Image is required! Tap to upload' : 'Tap to upload image',
                                        style: TextStyle(
                                          color: showImageError ? Colors.red : Colors.grey,
                                          fontWeight: showImageError ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    if (showImageError) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Category image is required',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildLabel('Background Color'),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Pick a color!'),
                              content: SingleChildScrollView(
                                child: BlockPicker(
                                  pickerColor: _parseColor(colorCtrl.text),
                                  onColorChanged: (color) {
                                    setStateDialog(() {
                                      colorCtrl.text = _colorToHex(color);
                                    });
                                  },
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Done'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _parseColor(colorCtrl.text),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(
                            'Pick Color',
                            style: TextStyle(
                              color: _parseColor(colorCtrl.text).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final name = labelCtrl.text.trim();
                                if (name.isEmpty) {
                                  AppToast.warning(context, 'Please enter category name');
                                  return;
                                }

                                if (selectedImageBytes == null && (currentImageUrl == null || currentImageUrl.isEmpty)) {
                                  setStateDialog(() => showImageError = true);
                                  AppToast.warning(context, 'Please select a category image');
                                  return;
                                }

                                setStateDialog(() => isUploading = true);
                                try {
                                  String imageUrl = currentImageUrl ?? '';

                                  if (selectedImageBytes != null) {
                                    try {
                                      final uri = Uri.parse('${AppConfig.apiUrl}/admin/categories/upload');
                                      final request = http.MultipartRequest('POST', uri);
                                      request.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                                      request.fields['type'] = 'category';
                                      request.fields['name'] = name;
                                      request.files.add(_buildImageMultipartFile(selectedImageBytes!, 'category.jpg'));
                                      final streamedRes = await request.send();
                                      final res = await http.Response.fromStream(streamedRes);
                                      if (res.statusCode == 200 || res.statusCode == 201) {
                                        final data = jsonDecode(res.body);
                                        final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
                                        if (uploadedUrl != null && uploadedUrl.toString().trim().isNotEmpty) {
                                          imageUrl = uploadedUrl.toString().trim();
                                        } else {
                                          throw Exception('Upload response did not return an image URL');
                                        }
                                      } else {
                                        throw Exception('Image upload failed (${res.statusCode})');
                                      }
                                    } catch (e) {
                                      debugPrint('Error uploading category image: $e');
                                      if (mounted) {
                                        AppToast.error(context, 'Failed to upload image: $e');
                                      }
                                      return;
                                    }
                                  }

                                  if (imageUrl.isEmpty) {
                                    if (mounted) {
                                      AppToast.warning(context, 'Category image is required');
                                    }
                                    return;
                                  }

                                  final body = {
                                    'label': name,
                                    'name': name,
                                    'color': colorCtrl.text.trim(),
                                    'image': imageUrl,
                                    'image_url': imageUrl,
                                  };

                                  final http.Response res;
                                  if (isEdit) {
                                    body['id'] = category['id'];
                                    res = await http.patch(
                                      Uri.parse('${AppConfig.apiUrl}/admin/categories'),
                                      headers: CubePod.get<AuthRepository>().authHeaders,
                                      body: jsonEncode(body),
                                    );
                                  } else {
                                    res = await http.post(
                                      Uri.parse('${AppConfig.apiUrl}/admin/categories'),
                                      headers: CubePod.get<AuthRepository>().authHeaders,
                                      body: jsonEncode(body),
                                    );
                                  }

                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (mounted) {
                                      AppToast.success(
                                        context,
                                        isEdit ? 'Category updated successfully' : 'Category created successfully',
                                      );
                                      _fetchCategories();
                                    }
                                  } else {
                                    String errorMsg = 'Failed to save category';
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
                                  debugPrint('Error saving category: $e');
                                  if (mounted) {
                                    AppToast.error(context, 'Error saving category: $e');
                                  }
                                } finally {
                                  setStateDialog(() => isUploading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF389758),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                isEdit ? 'Update Category' : 'Create Category',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () async {
                            await _deleteCategory(category['id']);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete Category'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D2D2D),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(dynamic cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Category?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${cat['label'] ?? cat['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory(cat['id']);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF185B3A),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Manage Categories',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_categories.length} Total',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categories',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Tap to edit or manage category details',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showCategoryDialog(),
                            icon: const Icon(Icons.add_rounded, size: 17, color: Colors.white),
                            label: Text(
                              'Add New',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF185B3A),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                          : _categories.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.category_outlined, size: 48, color: Color(0xFF94A3B8)),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No categories found',
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                                  itemCount: _categories.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final cat = _categories[index];
                                    final name = (cat['label'] ?? cat['name'] ?? '').toString();
                                    final imageUrl = (cat['image'] ?? cat['image_url'] ?? '').toString();
                                    final colorHex = (cat['color'] ?? cat['color_hex'] ?? '#185B3A').toString();
                                    final color = _parseColor(colorHex);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        leading: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: imageUrl.isNotEmpty
                                              ? Image.network(
                                                  imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Icon(Icons.category_rounded, color: color, size: 24),
                                                )
                                              : Icon(Icons.category_rounded, color: color, size: 24),
                                        ),
                                        title: Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              colorHex.toUpperCase(),
                                              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF185B3A)),
                                              onPressed: () => _showCategoryDialog(category: cat),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                              onPressed: () => _confirmDeleteCategory(cat),
                                            ),
                                          ],
                                        ),
                                        onTap: () => _showCategoryDialog(category: cat),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef ManageCategoriesPage = CategoriesPage;

