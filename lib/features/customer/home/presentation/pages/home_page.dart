import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/presentation/widgets/customer_top_bar.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/customer/home/data/repositories/product_repository.dart';
import 'package:app/core/widgets/skeleton_image.dart';
import 'package:app/features/customer/home/presentation/pages/product_detail_page.dart';
import 'package:app/features/customer/home/presentation/widgets/home_search_component.dart';
import 'package:app/features/customer/home/presentation/pages/filter_page.dart';
import 'package:app/features/customer/home/presentation/pages/see_more_page.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';
import 'package:app/features/customer/presentation/widgets/favorite_button.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/customer/home/presentation/pages/location_picker_page.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/customer/profile/presentation/pages/saved_addresses_page.dart';
import 'package:app/features/customer/home/presentation/pages/campaign_deals_page.dart';
import 'package:app/features/customer/explore/presentation/pages/promotions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _searchAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _searchAnimation = CurvedAnimation(
    parent: _searchAnimationController,
    curve: Curves.easeInOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );
  final TextEditingController _homeSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _searchBarKey = GlobalKey();
  double _searchStartY = 110.0;
  bool _isSearchOpen = false;
  int _searchCategoryIndex = 0;

  int _currentBannerIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 1.0);
  Timer? _timer;

  List<dynamic> _categories = [];
  List<dynamic> _todaysChoice = [];
  List<dynamic> _specialDeals = [];
  List<dynamic> _popularItems = [];
  List<dynamic> _promotions = [];
  List<dynamic> _otherProducts = [];
  String? _userLocation;
  bool _isLocationSheetOpen = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final repo = CubePod.get<ProductRepository>();
    _categories = repo.getCachedCategories();
    _promotions = repo.getCachedHomeDeals();
    _todaysChoice = repo.getCachedTodaysChoice();
    _specialDeals = repo.getCachedSpecialDeals();
    _popularItems = repo.getCachedPopularItems();
    _isLoading = _categories.isEmpty && _todaysChoice.isEmpty && _promotions.isEmpty;

    _startAutoSlide();
    _fetchData();
    _loadUserLocation();
    Future.delayed(const Duration(milliseconds: 800), _checkAndPromptUsername);
  }

  Future<void> _loadUserLocation() async {
    final userRepo = CubePod.get<UserRepository>();
    final authRepo = CubePod.get<AuthRepository>();

    // Preload addresses into in-memory cache right away
    if (authRepo.isLoggedIn) {
      userRepo.getCachedAddresses().ignore();
    }

    final prefs = await SharedPreferences.getInstance();
    String? loc = prefs.getString('user_location');
    if ((loc == null || loc.isEmpty) && authRepo.isLoggedIn) {
      try {
        final cached = await userRepo.getCachedAddresses();
        if (cached.isNotEmpty) {
          final defaultAddr = cached.firstWhere(
            (a) => a['is_default'] == true,
            orElse: () => cached.first,
          );
          loc = '${defaultAddr['street'] ?? ''}';
          if (loc.isNotEmpty) {
            await prefs.setString('user_location', loc);
          }
        } else {
          final headers = CubePod.get<AuthRepository>().authHeaders;
          final addresses = await userRepo.fetchAddresses(headers);
          if (addresses.isNotEmpty) {
            final defaultAddr = addresses.firstWhere(
              (a) => a['is_default'] == true,
              orElse: () => addresses.first,
            );
            loc = '${defaultAddr['street'] ?? ''}';
            if (loc.isNotEmpty) {
              await prefs.setString('user_location', loc);
            }
          }
        }
      } catch (e) {
        debugPrint('Error preloading user location: $e');
      }
    }
    if (mounted) {
      setState(() {
        _userLocation = loc;
      });
    }
  }

  Future<void> _checkAndPromptUsername() async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) return;

    try {
      final userRepo = CubePod.get<UserRepository>();
      final profile = await userRepo.fetchMyProfile(authRepo.authHeaders);
      final currentUsername = profile['username']?.toString() ?? '';

      // If username is empty or starts with 'user_' (auto-generated placeholder for Google / OAuth sign-in)
      if (currentUsername.isEmpty || currentUsername.startsWith('user_')) {
        if (!mounted) return;
        _showUsernamePromptDialog(currentUsername);
      }
    } catch (e) {
      debugPrint('[HomePage] Error checking username: $e');
    }
  }

  void _showUsernamePromptDialog(String initialUsername) {
    final controller = TextEditingController(text: initialUsername.startsWith('user_') ? '' : initialUsername);
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            content: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogCtx),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.alternate_email_rounded, color: Color(0xFF2E8B57), size: 28),
                      ),
                    ),
                const SizedBox(height: 16),
                Text(
                  'Choose Your Username',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a unique username to represent your profile on the Leaderboard and community rankings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: errorMessage != null ? Colors.red : const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: controller,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                      LengthLimitingTextInputFormatter(30),
                    ],
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      prefixText: '@ ',
                      prefixStyle: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E8B57),
                      ),
                      hintText: 'your_username',
                      hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: GoogleFonts.outfit(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final raw = controller.text.trim().toLowerCase();
                            if (raw.length < 3) {
                              setDialogState(() => errorMessage = 'Username must be at least 3 characters');
                              return;
                            }
                            setDialogState(() {
                              isSubmitting = true;
                              errorMessage = null;
                            });
                            try {
                              final messenger = ScaffoldMessenger.of(context);
                              final authRepo = CubePod.get<AuthRepository>();
                              final success = await CubePod.get<UserRepository>().updateProfile(
                                authRepo.authHeaders,
                                {'username': raw},
                              );
                              if (success) {
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Username set to @$raw!'),
                                    backgroundColor: const Color(0xFF2E8B57),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              } else {
                                setDialogState(() => errorMessage = 'Username is already taken or invalid.');
                              }
                            } catch (e) {
                              setDialogState(() => errorMessage = 'Failed to update username.');
                            } finally {
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Save & Continue',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
      ),
    );
  }

  Future<void> _fetchData() async {
    final repo = CubePod.get<ProductRepository>();
    if (mounted) setState(() => _isLoading = true);

    try {
      await Future.wait([
        repo.fetchCategoriesHome().then((data) {
          if (mounted) setState(() => _categories = data);
        }),
        repo.fetchHomeDeals().then((promos) {
          if (mounted) setState(() => _promotions = promos);
        }),
        repo.fetchTodaysChoice().then((data) {
          if (mounted) setState(() => _todaysChoice = data);
        }),
        repo.fetchSpecialDeals().then((data) {
          if (mounted) setState(() => _specialDeals = data);
        }),
        repo.fetchPopularItems().then((data) {
          if (mounted) setState(() => _popularItems = data);
        }),
        repo.fetchOtherItems().then((data) {
          if (mounted) setState(() => _otherProducts = data);
        }),
      ]);
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients && _promotions.isNotEmpty) {
        int nextPage = _currentBannerIndex + 1;
        if (nextPage >= _promotions.length) {
          nextPage = 0;
        }
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    _homeSearchController.dispose();
    _searchFocusNode.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showLocationBottomSheet() async {
    setState(() {
      _isLocationSheetOpen = true;
    });

    final isLoggedIn = CubePod.get<AuthRepository>().isLoggedIn;
    final userRepo = CubePod.get<UserRepository>();

    // Instant in-memory addresses (0ms)
    List<Map<String, dynamic>> savedAddresses = userRepo.getInMemoryAddresses();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choose Delivery Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (savedAddresses.isNotEmpty) ...[
                          const Text(
                            'SAVED ADDRESSES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...savedAddresses.map((addr) {
                            final street = addr['street']?.toString() ?? '';
                            final label = addr['label']?.toString() ?? 'Address';
                            final isSelected = _userLocation == street;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF0F9F4) : const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF42A769) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Icon(
                                  label.toLowerCase() == 'home'
                                      ? Icons.home_rounded
                                      : (label.toLowerCase() == 'office' || label.toLowerCase() == 'work')
                                          ? Icons.work_rounded
                                          : Icons.location_on_rounded,
                                  color: const Color(0xFF42A769),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (addr['is_default'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E9),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Default',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF42A769),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  street,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF42A769))
                                    : null,
                                onTap: () async {
                                  await CubePod.get<UserRepository>().setSelectedAddress(addr);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('user_location', street);
                                  if (mounted) {
                                    setState(() {
                                      _userLocation = street;
                                    });
                                  }
                                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                                },
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                        if (isLoggedIn)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.bookmark_border_rounded, color: Color(0xFF42A769)),
                            title: const Text(
                              'Manage Saved Addresses',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D2D2D),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SavedAddressesPage()),
                              );
                              _loadUserLocation();
                            },
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.add_location_alt_outlined,
                            color: Color(0xFF42A769),
                          ),
                          title: const Text(
                            'Set location on Map',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () async {
                            if (!CubePod.get<AuthRepository>().isLoggedIn) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AuthPage()),
                              );
                              return;
                            }
                            Navigator.pop(sheetContext);
                            final newLocation = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const LocationPickerPage(isAddingNewAddress: true),
                              ),
                            );
                            if (newLocation != null) {
                              setState(() {
                                _userLocation = newLocation as String;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
      },
    );
    if (mounted) {
      setState(() {
        _isLocationSheetOpen = false;
      });
    }
  }

  void _openSearch({int categoryIndex = 0}) {
    final box = _searchBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final topPadding = MediaQuery.paddingOf(context).top;
      final offset = box.localToGlobal(Offset.zero);
      _searchStartY = (offset.dy - topPadding).clamp(0.0, 800.0);
    } else {
      _searchStartY = 84.0;
    }
    setState(() {
      _isSearchOpen = true;
      _searchCategoryIndex = categoryIndex;
    });
    _searchAnimationController.forward().then((_) {
      if (mounted && _isSearchOpen) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _homeSearchController.clear();
    _searchAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSearchOpen = false;
        });
      }
    });
  }

  Widget _buildSingleSearchBox({required bool isFloating}) {
    return GestureDetector(
      onTap: () {
        if (!_isSearchOpen) {
          _openSearch();
        }
      },
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              color: Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isFloating
                  ? TextField(
                      controller: _homeSearchController,
                      focusNode: _searchFocusNode,
                      readOnly: !_isSearchOpen,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search for fruits, vegetables, meat...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      'Search for fruits, vegetables, meat...',
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (isFloating)
              AnimatedBuilder(
                animation: _homeSearchController,
                builder: (context, _) {
                  if (_isSearchOpen && _homeSearchController.text.isNotEmpty) {
                    return GestureDetector(
                      onTap: () {
                        _homeSearchController.clear();
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.close, size: 18, color: Colors.grey),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilterPage()),
                );
              },
              child: Icon(
                Icons.tune,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScrollView() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _showLocationBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF42A769),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivering to',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              _userLocation ?? 'Set Location',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isLocationSheetOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // The Movable Search Bar in the Home Section
            Padding(
              key: _searchBarKey,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: AnimatedBuilder(
                animation: _searchAnimation,
                builder: (context, _) {
                  return Opacity(
                    opacity: (_searchAnimation.value > 0.0 || _isSearchOpen) ? 0.0 : 1.0,
                    child: _buildSingleSearchBox(isFloating: false),
                  );
                },
              ),
            ),

            if (_isLoading && _categories.isEmpty && _promotions.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF185B3A)),
                ),
              ),
            ] else if (_isCatalogEmpty) ...[
              _buildEmptyCatalogState(),
            ] else ...[
              const SizedBox(height: 10),
              _buildCategories(),
              if (_todaysChoice.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildTodaysChoice(),
              ],
              if (_popularItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildPopularItems(),
              ],
              if (_otherProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildOtherItems(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSearchOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearchOpen) {
          _closeSearch();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // 1. Home Catalog View (Movable with topbar)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _searchAnimation,
                    builder: (context, _) {
                      return Opacity(
                        opacity: (1.0 - _searchAnimation.value).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: _isSearchOpen,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CustomerTopBar(),
                              Expanded(child: _buildHomeScrollView()),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Search Results View (Under top area when searching)
                Positioned.fill(
                  top: 54.0,
                  child: AnimatedBuilder(
                    animation: _searchAnimation,
                    builder: (context, _) {
                      if (_searchAnimation.value == 0.0 && !_isSearchOpen) {
                        return const SizedBox.shrink();
                      }
                      return Opacity(
                        opacity: _searchAnimation.value.clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: !_isSearchOpen,
                          child: HomeSearchComponent(
                            searchController: _homeSearchController,
                            initialCategoryIndex: _searchCategoryIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. The Animated Search Bar (Direct Positioned child of Stack)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _searchAnimation,
                    builder: (context, _) {
                      if (_searchAnimation.value == 0.0 && !_isSearchOpen) {
                        return const SizedBox.shrink();
                      }

                      final yOffset = (_searchStartY - 4.0) * (1.0 - _searchAnimation.value);

                      return Transform.translate(
                        offset: Offset(0, yOffset),
                        child: Container(
                          color: const Color(0xFFF8F9FA),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _searchAnimation.value,
                                  child: Opacity(
                                    opacity: _searchAnimation.value,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: IconButton(
                                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                                        onPressed: _closeSearch,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _buildSingleSearchBox(isFloating: true),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isCatalogEmpty =>
      !_isLoading &&
      _categories.isEmpty &&
      _promotions.isEmpty &&
      _todaysChoice.isEmpty &&
      _specialDeals.isEmpty &&
      _popularItems.isEmpty &&
      _otherProducts.isEmpty;

  Widget _buildEmptyCatalogState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 28,
                color: Color(0xFF185B3A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No products, categories, or deals found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'The catalog is currently empty. Items will appear once added in the store.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildBannerList() {

    if (_isLoading && _promotions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 182,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5EE), Color(0xFFF1F8F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFC7E6D7), width: 1.2),
          ),
        ),
      );
    }

    if (_promotions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 182,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentBannerIndex = index;
            });
          },
          itemCount: _promotions.length,
          itemBuilder: (context, index) {
            final promo = _promotions[index];
            final title = promo['title']?.toString() ?? '';
            final subtitle = (promo['subtitle'] ?? promo['description'])?.toString() ?? '';
            final badge = promo['badge_text']?.toString() ?? '';
            final btnText = promo['button_text']?.toString() ?? 'Shop Now';
            final image = promo['image_url']?.toString() ?? '';

            final Color bgColor = _parseHexColor(
              promo['bg_color']?.toString(),
              const Color(0xFFE8F5EE),
            );
            final Color btnColor = _parseHexColor(
              promo['button_color']?.toString(),
              const Color(0xFF185B3A),
            );

            final Map<String, dynamic> campaignData = Map<String, dynamic>.from(promo);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CampaignDealsPage(campaign: campaignData),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: btnColor.withValues(alpha: 0.18), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: btnColor.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      // Left Text Column
                      Expanded(
                        flex: 11,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (badge.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: btnColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: btnColor.withValues(alpha: 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 12,
                                        color: btnColor,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        badge,
                                        style: GoogleFonts.outfit(
                                          color: btnColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF475569),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: btnColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: btnColor.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      btnText,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Image with Signature "C" Curve
                      if (image.isNotEmpty)
                        Expanded(
                          flex: 9,
                          child: ClipPath(
                            clipper: const CCurveClipper(),
                            child: SizedBox.expand(
                              child: Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: btnColor.withValues(alpha: 0.08),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: btnColor,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaginationDots() {
    if (_promotions.length <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _promotions.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentBannerIndex == index ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: _currentBannerIndex == index
                ? const Color(0xFF185B3A)
                : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) return Icons.eco_rounded;
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg') || n.contains('breakfast')) return Icons.egg_outlined;
    if (n.contains('beverage') || n.contains('drink') || n.contains('tea') || n.contains('coffee') || n.contains('juice')) return Icons.local_cafe_outlined;
    if (n.contains('bakery') || n.contains('bread') || n.contains('snack') || n.contains('cookie')) return Icons.bakery_dining_outlined;
    if (n.contains('organic') || n.contains('farm') || n.contains('honey') || n.contains('ghee')) return Icons.spa_rounded;
    return Icons.grid_view_rounded;
  }

  Color _getCategoryColor(String name, String? hex) {
    if (hex != null && hex.isNotEmpty) {
      try {
        final cleanHex = hex.replaceAll('#', '');
        return Color(int.parse('FF$cleanHex', radix: 16));
      } catch (_) {}
    }
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) return const Color(0xFF185B3A);
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg')) return const Color(0xFFD97706);
    if (n.contains('beverage') || n.contains('drink')) return const Color(0xFF0284C7);
    if (n.contains('bakery') || n.contains('snack')) return const Color(0xFFE11D48);
    if (n.contains('organic')) return const Color(0xFF059669);
    return const Color(0xFF185B3A);
  }

  Widget _buildCategories() {
    if (_isLoading && _categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Shop by Categories',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 54,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shop by Categories',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _openSearch();
                },
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF185B3A),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF185B3A),
                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Categories Horizontal Scroll with Edge-to-Edge Padding & Zero Stretching
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final name = cat['label'] ?? cat['name'] ?? 'Category';
              final image = cat['image'] ?? cat['image_url'];
              final colorHex = cat['color_hex'];
              final themeColor = _getCategoryColor(name, colorHex);
              final iconData = _getCategoryIcon(name);
              final hasImage = image != null && image.toString().trim().isNotEmpty;

              return GestureDetector(
                onTap: () {
                  _openSearch(categoryIndex: index);
                },
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: hasImage
                              ? ClipOval(
                                  child: Image.network(
                                    image.toString(),
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      iconData,
                                      color: themeColor,
                                      size: 26,
                                    ),
                                  ),
                                )
                              : Icon(
                                  iconData,
                                  color: themeColor,
                                  size: 26,
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 28,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionWithSeeMore({
    required String title,
    required List<dynamic> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SeeMorePage(title: title, products: products),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'See more',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF185B3A),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF185B3A),
                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 224,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: products
                .map(
                  (product) => _buildProductCard(
                    id: product['id'],
                    image: product['image'] ?? '',
                    title: product['title'] ?? '',
                    price: product['price'] ?? '',
                    unit: product['unit'] ?? '',
                    originalPrice: product['original_price'] ?? '',
                    description: product['description'],
                    rating: product['avg_rating'],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysChoice() {
    if (_todaysChoice.isEmpty) return const SizedBox();
    return _buildSectionWithSeeMore(
      title: "Today's Picks",
      products: _todaysChoice,
    );
  }

  Widget _buildSpecialDeal() {
    if (_specialDeals.isEmpty) return const SizedBox();
    return _buildSectionWithSeeMore(
      title: 'Special Deal',
      products: _specialDeals,
    );
  }

  Widget _buildProductCard({
    required dynamic id,
    required String image,
    required String title,
    required String price,
    required String unit,
    required String originalPrice,
    String? description,
    dynamic rating,
  }) {
    String formattedPrice = price.startsWith('₹')
        ? price
        : price.replaceAll('Rs', '₹').trim();
    if (!formattedPrice.startsWith('₹')) formattedPrice = '₹$formattedPrice';

    String formattedOriginalPrice = originalPrice.replaceAll('Rs', '₹').trim();
    if (formattedOriginalPrice.isNotEmpty &&
        !formattedOriginalPrice.startsWith('₹')) {
      formattedOriginalPrice = '₹$formattedOriginalPrice';
    }

    // Calculate discount percent if available
    int discountPct = 0;
    try {
      final pVal = double.tryParse(formattedPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      final oVal = double.tryParse(formattedOriginalPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      if (oVal > pVal && oVal > 0) {
        discountPct = (((oVal - pVal) / oVal) * 100).round();
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              id: id,
              image: image,
              title: title,
              price: price,
              unit: unit,
              originalPrice: originalPrice,
              description: description,
              rating: rating,
            ),
          ),
        );
      },
      child: Container(
        width: 154,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product Image Container
                Container(
                  height: 108,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 32,
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: const Color(0xFF0F172A),
                            height: 1.18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating?.toString() ?? '4.8',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•  $unit',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formattedPrice,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (formattedOriginalPrice.isNotEmpty)
                            Text(
                              formattedOriginalPrice,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    CubePod.get<CartState>().addToCart(context, id);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (discountPct > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$discountPct% OFF',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(
                productId: id,
                iconSize: 16,
                padding: 6,
                hasShadow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularItems() {
    if (_popularItems.isEmpty) return const SizedBox();
    return _buildSectionWithSeeMore(
      title: 'Popular Items',
      products: _popularItems,
    );
  }

  Widget _buildOtherItems() {
    if (_otherProducts.isEmpty && !_isLoading) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Explore All Products',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _isLoading && _otherProducts.isEmpty
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.61,
                  ),
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 80, height: 12, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                                const SizedBox(height: 6),
                                Container(width: 50, height: 10, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                                const SizedBox(height: 8),
                                Container(width: 60, height: 14, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _otherProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.61,
                  ),
                  itemBuilder: (context, index) {
                    final product = _otherProducts[index] as Map<String, dynamic>;
                    return _buildProductCardForGrid(product: product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCardForGrid({required Map<String, dynamic> product}) {
    final image = product['image'] as String? ?? product['image_url'] as String? ?? '';
    final title = product['title'] as String? ?? 'No Title';

    // Process price
    int priceVal = 0;
    if (product['price'] != null) {
      if (product['price'] is int) {
        priceVal = product['price'];
      } else {
        priceVal =
            int.tryParse(
              product['price'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
      }
    }
    final price =
        '₹${priceVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

    final unit = product['unit'] as String? ?? '1 kg';

    // Process original price
    int origPriceVal = 0;
    if (product['original_price'] != null) {
      if (product['original_price'] is int) {
        origPriceVal = product['original_price'];
      } else {
        origPriceVal =
            int.tryParse(
              product['original_price'].toString().replaceAll(
                RegExp(r'[^0-9]'),
                '',
              ),
            ) ??
            0;
      }
    }
    final originalPrice = origPriceVal > 0
        ? '₹${origPriceVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
        : '';

    int discountPct = 0;
    if (origPriceVal > priceVal && origPriceVal > 0) {
      discountPct = (((origPriceVal - priceVal) / origPriceVal) * 100).round();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              id: product['id'],
              image: image,
              title: title,
              price: price,
              unit: unit,
              originalPrice: originalPrice,
              description: product['description'],
              rating: product['avg_rating'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 34,
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product['avg_rating']?.toString() ?? '4.8',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•  $unit',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (originalPrice.isNotEmpty)
                            Text(
                              originalPrice,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    CubePod.get<CartState>().addToCart(context, product['id']);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_shopping_cart_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (discountPct > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$discountPct% OFF',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(
                productId: product['id'],
                iconSize: 16,
                padding: 6,
                hasShadow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PromotionsPage()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F6EF), Color(0xFFF4FAF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFBCE3D1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF185B3A).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 3D Discount Badge with Layered Depth
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF185B3A).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title & Subtitle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Save More with Offers',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: const Color(0xFF0F172A),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Explore coupons & mega discounts',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Premium Pill Action Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF185B3A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF185B3A).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Explore Offers',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Signature C-shaped curve clipper for campaign hero images
class CCurveClipper extends CustomClipper<Path> {
  const CCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start top-left
    path.moveTo(size.width * 0.16, 0);
    // Smooth C-shaped arc along the left edge
    path.quadraticBezierTo(
      0,
      size.height * 0.5,
      size.width * 0.16,
      size.height,
    );
    // Bottom-right corner
    path.lineTo(size.width, size.height);
    // Top-right corner
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Retain alias for backward compatibility
typedef GroceryHomePage = HomePage;
