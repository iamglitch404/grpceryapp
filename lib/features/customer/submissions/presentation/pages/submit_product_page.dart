import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/submissions/data/repositories/submission_repository.dart';
import 'package:app/core/widgets/product_qr_sheet.dart';

class SubmitProductPage extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;

  const SubmitProductPage({super.key, this.initialProduct});

  @override
  State<SubmitProductPage> createState() => _SubmitProductPageState();
}

class _SubmitProductPageState extends State<SubmitProductPage> {
  final _formKey = GlobalKey<FormState>();
  final SubmissionRepository _repo = CubePod.get<SubmissionRepository>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(text: '1 kg');
  final TextEditingController _stockController = TextEditingController(text: '50');
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();

  // Pickup fields
  final TextEditingController _pickupAddressController = TextEditingController();
  final TextEditingController _pickupPhoneController = TextEditingController();
  String _selectedPickupTime = 'Morning (9 AM - 12 PM)';

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  String? _imageUrl;
  XFile? _selectedImage;
  bool _isSaving = false;

  bool _isActive = true;
  bool _isPopular = false;
  bool _isTodaysChoice = false;
  bool _isSpecialDeal = false;

  final List<String> _quickUnits = ['1 kg', '500 g', '250 g', '1 pc', '1 pack', '1 L', '500 ml'];
  final List<String> _pickupTimeSlots = [
    'Morning (9 AM - 12 PM)',
    'Afternoon (1 PM - 5 PM)',
    'Evening (5 PM - 8 PM)',
    'Tomorrow Morning (9 AM - 12 PM)',
    'Anytime Today',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    final user = CubePod.get<AuthRepository>().currentUser;
    _pickupPhoneController.text = user?['phone']?.toString() ?? '';

    if (widget.initialProduct != null) {
      final p = widget.initialProduct!;
      _titleController.text = p['title']?.toString() ?? '';

      final pricePaise = p['price_paise'] is int ? p['price_paise'] as int : int.tryParse(p['price_paise']?.toString() ?? '0') ?? 0;
      _priceController.text = (pricePaise / 100).toStringAsFixed(pricePaise % 100 == 0 ? 0 : 2);

      if (p['original_price_paise'] != null) {
        final origPaise = p['original_price_paise'] is int ? p['original_price_paise'] as int : int.tryParse(p['original_price_paise']?.toString() ?? '0') ?? 0;
        if (origPaise > 0) {
          _originalPriceController.text = (origPaise / 100).toStringAsFixed(origPaise % 100 == 0 ? 0 : 2);
        }
      }

      _unitController.text = p['unit']?.toString() ?? '1 kg';
      _stockController.text = (p['stock_quantity'] ?? 50).toString();
      _descController.text = p['description']?.toString() ?? '';
      _caloriesController.text = p['calories']?.toString() ?? '';
      _imageUrl = p['image_url']?.toString();

      _pickupAddressController.text = p['pickup_address']?.toString() ?? '';
      _pickupPhoneController.text = p['pickup_phone']?.toString() ?? _pickupPhoneController.text;
      _selectedPickupTime = p['pickup_time']?.toString() ?? _selectedPickupTime;

      _selectedCategoryId = p['category_id']?.toString();
      _selectedSubcategoryId = p['subcategory_id']?.toString();
      _isActive = p['is_active'] ?? true;
      _isPopular = p['is_popular'] ?? false;
      _isTodaysChoice = p['is_todays_choice'] ?? false;
      _isSpecialDeal = p['is_special_deal'] ?? false;
    }
  }

  Future<void> _loadCategories() async {
    final cats = await _repo.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (_selectedCategoryId == null && cats.isNotEmpty) {
          _selectedCategoryId = cats.first['id']?.toString();
          _updateSubcategoryOnCategoryChange();
        }
      });
    }
  }

  void _updateSubcategoryOnCategoryChange() {
    final cat = _categories.firstOrNullWhere((c) => c['id']?.toString() == _selectedCategoryId);
    final subs = (cat?['subcategories'] as List?) ?? [];
    if (subs.isNotEmpty) {
      _selectedSubcategoryId = subs.first['id']?.toString();
    } else {
      _selectedSubcategoryId = null;
    }
  }

  List<Map<String, dynamic>> get _currentSubcategories {
    final cat = _categories.firstOrNullWhere((c) => c['id']?.toString() == _selectedCategoryId);
    final subs = cat?['subcategories'];
    if (subs is List) {
      return List<Map<String, dynamic>>.from(subs);
    }
    return [];
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1000,
    );

    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authRepo = CubePod.get<AuthRepository>();
    final title = _titleController.text.trim();
    final priceStr = _priceController.text.trim();
    final origPriceStr = _originalPriceController.text.trim();
    final unit = _unitController.text.trim();
    final stockStr = _stockController.text.trim();
    final desc = _descController.text.trim();
    final calories = _caloriesController.text.trim();
    final pickupAddress = _pickupAddressController.text.trim();
    final pickupPhone = _pickupPhoneController.text.trim();

    final price = double.tryParse(priceStr) ?? 0.0;
    final pricePaise = (price * 100).round();

    int? origPricePaise;
    if (origPriceStr.isNotEmpty) {
      final origPrice = double.tryParse(origPriceStr) ?? 0.0;
      if (origPrice > 0) {
        origPricePaise = (origPrice * 100).round();
      }
    }

    final stock = int.tryParse(stockStr) ?? 50;

    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _imageUrl;

      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final uploaded = await _repo.uploadProductImage(
          authRepo.authHeaders,
          bytes,
          _selectedImage!.name,
        );
        if (uploaded != null) {
          finalImageUrl = uploaded;
        }
      }

      final Map<String, dynamic> payload = {
        'title': title,
        'price_paise': pricePaise,
        'unit': unit.isNotEmpty ? unit : '1 kg',
        'stock_quantity': stock,
        'pickup_address': pickupAddress,
        'pickup_phone': pickupPhone,
        'pickup_time': _selectedPickupTime,
        'is_popular': _isPopular,
        'is_todays_choice': _isTodaysChoice,
        'is_special_deal': _isSpecialDeal,
      };

      if (finalImageUrl != null && finalImageUrl.isNotEmpty) {
        payload['image_url'] = finalImageUrl;
      }
      if (_selectedCategoryId != null) {
        payload['category_id'] = _selectedCategoryId;
      }
      if (_selectedSubcategoryId != null) {
        payload['subcategory_id'] = _selectedSubcategoryId;
      }
      if (origPricePaise != null) {
        payload['original_price_paise'] = origPricePaise;
      }
      if (desc.isNotEmpty) {
        payload['description'] = desc;
      }
      if (calories.isNotEmpty) {
        payload['calories'] = calories;
      }

      if (widget.initialProduct != null) {
        final id = widget.initialProduct!['id']?.toString() ?? '';
        payload['is_active'] = _isActive;
        final success = await _repo.updateProduct(authRepo.authHeaders, id, payload);

        if (success && mounted) {
          _showToast('Product updated successfully!');
          Navigator.pop(context, true);
        } else {
          throw Exception('Failed to update product');
        }
      } else {
        final result = await _repo.submitProductForApproval(authRepo.authHeaders, payload);

        if (result != null && mounted) {
          _showToast('Product submitted! Admin will schedule pickup.');

          final createdProduct = result['product'] ?? payload;
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ProductQrSheet(product: createdProduct),
          );

          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          throw Exception('Failed to submit product');
        }
      }
    } catch (e) {
      debugPrint('[UploadProductPage] save error: $e');
      if (mounted) _showToast(e.toString().replaceAll('Exception:', '').trim(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        backgroundColor: isError ? const Color(0xFFE11D48) : const Color(0xFF185B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialProduct != null;
    final subcategories = _currentSubcategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF9),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Product' : 'Upload Product',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProduct,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF185B3A)),
                  )
                : Text(
                    isEditing ? 'Save' : 'Submit',
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
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            // ── 1. Image Upload Box ──
            _buildImagePickerCard(),

            const SizedBox(height: 18),

            // ── 2. Product Details & Category Hierarchy ──
            _buildSectionTitle('CLASSIFICATION & DETAILS'),
            const SizedBox(height: 6),
            _buildCard([
              _buildTextField(
                controller: _titleController,
                label: 'Product Name',
                hint: 'e.g. Farm Fresh Alphonso Mangoes',
                icon: Icons.shopping_basket_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter product name' : null,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Top-level Category Selector
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.category_outlined, size: 18, color: Color(0xFF185B3A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Main Store Category',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategoryId,
                            isExpanded: true,
                            hint: Text(
                              'Select Category',
                              style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: _categories.map((c) {
                              final id = c['id']?.toString() ?? '';
                              final label = c['label'] ?? c['name'] ?? 'Category';
                              return DropdownMenuItem<String>(
                                value: id,
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategoryId = val;
                                  _updateSubcategoryOnCategoryChange();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Subcategory Selector
              if (subcategories.isNotEmpty) ...[
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subcategory (Classification)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubcategoryId,
                              isExpanded: true,
                              hint: Text(
                                'Select Subcategory',
                                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                              ),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: subcategories.map((s) {
                                final id = s['id']?.toString() ?? '';
                                final label = s['name'] ?? 'Subcategory';
                                return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(
                                    label,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedSubcategoryId = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ]),

            const SizedBox(height: 18),

            // ── 3. Pricing & Inventory ──
            _buildSectionTitle('PRICING & INVENTORY'),
            const SizedBox(height: 6),
            _buildCard([
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: 'Selling Price (₹)',
                      hint: '99',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextField(
                      controller: _originalPriceController,
                      label: 'MRP / Original (₹)',
                      hint: '120 (Optional)',
                      icon: Icons.discount_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _unitController,
                      label: 'Unit / Weight',
                      hint: '1 kg, 500 g',
                      icon: Icons.scale_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Stock Quantity',
                      hint: '50',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Unit Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickUnits.map((u) {
                  final isSelected = _unitController.text == u;
                  return InkWell(
                    onTap: () => setState(() => _unitController.text = u),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE8F5EE) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        u,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]),

            const SizedBox(height: 18),

            // ── 4. Pickup & Dispatch Information ──
            _buildSectionTitle('PICKUP & LOGISTICS INFORMATION'),
            const SizedBox(height: 6),
            _buildCard([
              _buildTextField(
                controller: _pickupAddressController,
                label: 'Pickup Address / Location',
                hint: 'House/Shop No, Street, Landmark, City',
                icon: Icons.location_on_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Pickup address is required for item collection' : null,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              _buildTextField(
                controller: _pickupPhoneController,
                label: 'Pickup Contact Phone',
                hint: '+977 9800000000',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact phone is required' : null,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Preferred Pickup Slot
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF185B3A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferred Pickup Slot',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPickupTime,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: _pickupTimeSlots.map((slot) {
                              return DropdownMenuItem<String>(
                                value: slot,
                                child: Text(
                                  slot,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedPickupTime = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 18),

            // ── 5. Description & Nutrition ──
            _buildSectionTitle('DESCRIPTION & NUTRITION (OPTIONAL)'),
            const SizedBox(height: 6),
            _buildCard([
              _buildTextField(
                controller: _descController,
                label: 'Short Description',
                hint: 'Freshly harvested organic items directly from local growers...',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildTextField(
                controller: _caloriesController,
                label: 'Calories / Details',
                hint: 'e.g. 52 kcal / 100g',
                icon: Icons.local_fire_department_outlined,
              ),
            ]),

            const SizedBox(height: 26),

            // ── Submit Button ──
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? 'Save Product Changes' : 'Submit & Generate QR Pass',
                            style: GoogleFonts.outfit(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
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

  Widget _buildImagePickerCard() {
    final hasImage = _selectedImage != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

    return Container(
      width: double.infinity,
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
        children: [
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _selectedImage != null
                        ? (kIsWeb
                            ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                            : Image.file(File(_selectedImage!.path), fit: BoxFit.cover))
                        : Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_rounded, size: 40, color: Color(0xFF94A3B8)),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                        _imageUrl = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF185B3A)),
                    label: Text(
                      hasImage ? 'Change Photo' : 'Gallery',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF185B3A)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF185B3A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Colors.white),
                    label: Text(
                      'Camera',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 6 : 0),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5EE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 18, color: const Color(0xFF185B3A)),
            ),
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
              const SizedBox(height: 2),
              TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                maxLines: maxLines,
                validator: validator,
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  hintText: hint,
                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13.5),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? firstOrNullWhere(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// Retain alias for backward compatibility
typedef UploadProductPage = SubmitProductPage;
