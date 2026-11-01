import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/screens/locationPickerPage.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class SavedAddressesPage extends ConsumerStatefulWidget {
  final bool isSelecting;
  const SavedAddressesPage({super.key, this.isSelecting = false});

  @override
  ConsumerState<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends ConsumerState<SavedAddressesPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> get _addresses => ref.watch(savedAddressesListProvider);
  bool get _isLoading => ref.watch(savedAddressesLoadingProvider);
  late AnimationController _skeletonAnimController;
  late Animation<Color?> _skeletonColorAnimation;

  @override
  void initState() {
    super.initState();
    _skeletonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonColorAnimation = ColorTween(
      begin: const Color(0xFFEBECEF),
      end: const Color(0xFFD9DBE0),
    ).animate(_skeletonAnimController);

    _loadAddresses();
  }

  @override
  void dispose() {
    _skeletonAnimController.dispose();
    super.dispose();
  }

  /// Loads addresses:
  /// 1. Immediately renders cached addresses from device storage (zero lag).
  /// 2. If no cache exists, keeps skeleton loading.
  /// 3. Validates and syncs with backend server in background (Stale-While-Revalidate).
  Future<void> _loadAddresses() async {
    final userRepo = ref.read(userRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);

    if (!authRepo.isLoggedIn) {
      if (mounted) {
        ref.read(savedAddressesListProvider.notifier).state = [];
        ref.read(savedAddressesLoadingProvider.notifier).state = false;
      }
      return;
    }

    // Step 1: Check and load from device cache first
    final hasCache = await userRepo.hasAddressCache();
    final cached = await userRepo.getCachedAddresses();
    if ((hasCache || cached.isNotEmpty) && mounted) {
      ref.read(savedAddressesListProvider.notifier).state = cached;
      ref.read(savedAddressesLoadingProvider.notifier).state = false;
    }

    // Step 2: Fetch fresh from server (sync offline deletes & update cache)
    try {
      final headers = authRepo.authHeaders;
      final serverAddresses = await userRepo.fetchAddresses(headers);

      if (mounted) {
        ref.read(savedAddressesListProvider.notifier).state = List<Map<String, dynamic>>.from(serverAddresses);
        ref.read(savedAddressesLoadingProvider.notifier).state = false;
      }
    } catch (e) {
      debugPrint('[SavedAddressesPage] Background sync error: $e');
      if (mounted) {
        ref.read(savedAddressesLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _handleDelete(int index) async {
    final addr = _addresses[index];
    final addrId = addr['id']?.toString() ?? '';
    if (addrId.isEmpty) return;

    // Optimistically remove from state immediately
    final list = List<Map<String, dynamic>>.from(ref.read(savedAddressesListProvider));
    list.removeAt(index);
    ref.read(savedAddressesListProvider.notifier).state = list;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Address "${addr['label'] ?? 'Address'}" deleted'),
            ],
          ),
          backgroundColor: const Color(0xFF2D2D2D),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Delete from local cache and sync/queue with DB
    try {
      final headers = ref.read(authRepositoryProvider).authHeaders;
      await ref.read(userRepositoryProvider).deleteAddress(headers, addrId);
    } catch (e) {
      debugPrint('[SavedAddressesPage] Error during address delete: $e');
    }
  }

  Future<void> _onAddNewAddressPressed() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(isAddingNewAddress: true),
      ),
    );
    _loadAddresses();
  }

  void _editAddress(int index) {
    final addr = _addresses[index];
    final labelController = TextEditingController(text: addr['label'] ?? '');
    final nameController = TextEditingController(text: addr['name'] ?? ref.read(authRepositoryProvider).currentUser?['name'] ?? '');
    final phoneController = TextEditingController(text: addr['phone'] ?? ref.read(authRepositoryProvider).currentUser?['phone'] ?? '');
    final addressController = TextEditingController(text: addr['street'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  labelText: 'Label (e.g. Home, Office, Work)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B6B44), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Recipient Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B6B44), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Recipient Phone Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B6B44), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Full Delivery Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1B6B44), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (labelController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty ||
                        phoneController.text.trim().isEmpty ||
                        addressController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields')),
                      );
                      return;
                    }
                    try {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final headers = ref.read(authRepositoryProvider).authHeaders;
                      final success = await ref.read(userRepositoryProvider).updateAddress(
                        headers,
                        addr['id'],
                        {
                          'label': labelController.text.trim(),
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'street': addressController.text.trim(),
                        },
                      );

                      if (success) {
                        _loadAddresses();
                        navigator.pop();
                      } else {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Failed to update address.')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error updating address: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B6B44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Shimmer Skeleton Loader for First Time Loading
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _skeletonColorAnimation,
          builder: (context, child) {
            final color = _skeletonColorAnimation.value ?? const Color(0xFFEBECEF);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0F1F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 80,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 16,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 14),
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 200,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Empty State Card (Matches Design Reference)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyStateCard() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Illustration directly on page
            Image.asset(
              'assets/images/empty_address.png',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 80,
                      color: Color(0xFF1B6B44),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'No saved addresses yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2022),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Save your delivery addresses to enjoy faster checkout and a smoother shopping experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF717784),
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Populated Address List
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAddressList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 20),
      itemCount: _addresses.length,
      itemBuilder: (context, index) {
        final addr = _addresses[index];
        final isDefault = addr['is_default'] == true;

        return GestureDetector(
          onTap: widget.isSelecting
              ? () async {
                  await ref.read(userRepositoryProvider).setSelectedAddress(addr);
                  if (context.mounted) {
                    Navigator.pop(context, addr);
                  }
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: widget.isSelecting
                  ? Border.all(color: const Color(0xFF1B6B44).withValues(alpha: 0.4), width: 1.5)
                  : Border.all(color: const Color(0xFFF0F1F3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            (addr['label']?.toString().toLowerCase() == 'home')
                                ? Icons.home_rounded
                                : (addr['label']?.toString().toLowerCase() == 'office' ||
                                        addr['label']?.toString().toLowerCase() == 'work')
                                    ? Icons.work_rounded
                                    : Icons.location_on_rounded,
                            size: 18,
                            color: const Color(0xFF1B6B44),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          addr['label'] as String? ?? 'Address',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2022),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B6B44),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!widget.isSelecting)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _editAddress(index),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Colors.grey.shade700,
                                size: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _handleDelete(index),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red.shade400,
                                size: 17,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF1B6B44),
                        size: 22,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 12),
                Text(
                  (addr['name'] ?? ref.read(authRepositoryProvider).currentUser?['name'] ?? '') as String,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (addr['phone'] ?? ref.read(authRepositoryProvider).currentUser?['phone'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (addr['street'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Bottom Action Button ("+ Add New Address")
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBottomButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _onAddNewAddressPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B44), // Deep forest emerald green matching reference
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF1B6B44),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Add New Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1E2022),
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Saved Addresses',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.4,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading && _addresses.isEmpty
            ? _buildSkeletonList()
            : !isLoggedIn
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Sign In Required',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please log in to your account to view and manage your saved delivery addresses.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFF1B6B44),
                    onRefresh: _loadAddresses,
                    child: _addresses.isEmpty
                        ? _buildEmptyStateCard()
                        : _buildAddressList(),
                  ),
        bottomNavigationBar: isLoggedIn ? _buildBottomButton() : null,
      ),
    );
  }
}
