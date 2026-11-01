import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/widgets/customerTopBar.dart';
import 'package:app/features/customer/home/screens/locationPickerPage.dart';
import 'package:app/features/customer/home/widgets/homeSearchBox.dart';
import 'package:app/features/customer/home/widgets/homeScrollView.dart';
import 'package:app/features/customer/home/widgets/homeSearchComponent.dart';
import 'package:app/features/customer/profile/screens/savedAddressesPage.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
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

  final PageController _pageController = PageController(viewportFraction: 1.0);
  Timer? _timer;

  HomeCatalogState get _catalog => ref.watch(homeCatalogProvider);
  List<dynamic> get _categories => _catalog.categories;
  List<dynamic> get _promotions => _catalog.promotions;
  List<dynamic> get _todaysChoice => _catalog.todaysChoice;
  List<dynamic> get _specialDeals => _catalog.specialDeals;
  List<dynamic> get _popularItems => _catalog.popularItems;
  List<dynamic> get _otherProducts => _catalog.otherProducts;
  String? get _userLocation => _catalog.userLocation;
  bool get _isLocationSheetOpen => _catalog.isLocationSheetOpen;
  bool get _isLoading => _catalog.isLoading;
  bool get _isSearchOpen => _catalog.isSearchOpen;
  int get _searchCategoryIndex => _catalog.searchCategoryIndex;
  int get _currentBannerIndex => _catalog.currentBannerIndex;

  bool get _isCatalogEmpty =>
      !_isLoading &&
      _categories.isEmpty &&
      _promotions.isEmpty &&
      _todaysChoice.isEmpty &&
      _specialDeals.isEmpty &&
      _popularItems.isEmpty &&
      _otherProducts.isEmpty;

  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
    _fetchData();
    _loadUserLocation();
    Future.delayed(const Duration(milliseconds: 800), _checkAndPromptUsername);

    final authNotifier = ref.read(authRepositoryProvider).authStateNotifier;
    _authListener = () {
      if (mounted) {
        _fetchData();
        _loadUserLocation();
        _checkAndPromptUsername();
      }
    };
    authNotifier.addListener(_authListener!);
  }

  Future<void> _loadUserLocation() async {
    final userRepo = ref.read(userRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);

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
          final headers = ref.read(authRepositoryProvider).authHeaders;
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
      ref.read(homeCatalogProvider.notifier).setUserLocation(loc);
    }
  }

  Future<void> _checkAndPromptUsername() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isLoggedIn) return;

    try {
      final userRepo = ref.read(userRepositoryProvider);
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
                                  final authRepo = ref.read(authRepositoryProvider);
                                  final success = await ref.read(userRepositoryProvider).updateProfile(
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
    final repo = ref.read(productRepositoryProvider);
    final notifier = ref.read(homeCatalogProvider.notifier);

    final currentState = ref.read(homeCatalogProvider);
    final hasExistingData = currentState.categories.isNotEmpty ||
        currentState.promotions.isNotEmpty ||
        currentState.todaysChoice.isNotEmpty ||
        currentState.specialDeals.isNotEmpty ||
        currentState.popularItems.isNotEmpty ||
        currentState.otherProducts.isNotEmpty;

    if (mounted && !hasExistingData) {
      notifier.setLoading(true);
    }

    try {
      await Future.wait([
        repo.fetchCategoriesHome().then((data) {
          if (mounted) notifier.setCategories(data);
        }),
        repo.fetchHomeDeals().then((promos) {
          if (mounted) notifier.setPromotions(promos);
        }),
        repo.fetchTodaysChoice().then((data) {
          if (mounted) notifier.setTodaysChoice(data);
        }),
        repo.fetchSpecialDeals().then((data) {
          if (mounted) notifier.setSpecialDeals(data);
        }),
        repo.fetchPopularItems().then((data) {
          if (mounted) notifier.setPopularItems(data);
        }),
        repo.fetchOtherItems().then((data) {
          if (mounted) notifier.setOtherProducts(data);
        }),
      ]).timeout(const Duration(seconds: 6));

      // Fallback: If sections are empty, fetch general active products
      final stateAfter = ref.read(homeCatalogProvider);
      if (stateAfter.todaysChoice.isEmpty &&
          stateAfter.specialDeals.isEmpty &&
          stateAfter.popularItems.isEmpty &&
          stateAfter.otherProducts.isEmpty) {
        final allProducts = await repo.fetchProducts();
        if (mounted && allProducts.isNotEmpty) {
          notifier.setOtherProducts(allProducts);
        }
      }
    } catch (e) {
      debugPrint('[HomePage] Error fetching home data: $e');
    } finally {
      if (mounted) {
        notifier.setLoading(false);
      }
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
    if (_authListener != null) {
      ref.read(authRepositoryProvider).authStateNotifier.removeListener(_authListener!);
    }
    _searchAnimationController.dispose();
    _homeSearchController.dispose();
    _searchFocusNode.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _showLocationBottomSheet() async {
    ref.read(homeCatalogProvider.notifier).setLocationSheetOpen(true);

    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
    final userRepo = ref.read(userRepositoryProvider);

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
                  const Expanded(
                    child: Text(
                      'Choose Delivery Location',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2022),
                      ),
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
                              await ref.read(userRepositoryProvider).setSelectedAddress(addr);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setString('user_location', street);
                              if (mounted) {
                                ref.read(homeCatalogProvider.notifier).setUserLocation(street);
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
                        if (!ref.read(authRepositoryProvider).isLoggedIn) {
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
                          ref.read(homeCatalogProvider.notifier).setUserLocation(newLocation as String);
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
      ref.read(homeCatalogProvider.notifier).setLocationSheetOpen(false);
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
    ref.read(homeCatalogProvider.notifier).setSearchOpen(true, categoryIndex: categoryIndex);
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
        ref.read(homeCatalogProvider.notifier).setSearchOpen(false);
      }
    });
  }

  Widget _buildSingleSearchBox({required bool isFloating}) {
    return HomeSearchBox(
      isFloating: isFloating,
      controller: _homeSearchController,
      focusNode: _searchFocusNode,
      isSearchOpen: _isSearchOpen,
      onTap: () {
        if (!_isSearchOpen) {
          _openSearch();
        }
      },
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
                              Expanded(
                                child: HomeScrollView(
                                  categories: _categories,
                                  promotions: _promotions,
                                  todaysChoice: _todaysChoice,
                                  specialDeals: _specialDeals,
                                  popularItems: _popularItems,
                                  otherProducts: _otherProducts,
                                  isLoading: _isLoading,
                                  isCatalogEmpty: _isCatalogEmpty,
                                  userLocation: _userLocation,
                                  isLocationSheetOpen: _isLocationSheetOpen,
                                  searchBarKey: _searchBarKey,
                                  pageController: _pageController,
                                  currentBannerIndex: _currentBannerIndex,
                                  onPageChanged: (index) {
                                    ref.read(homeCatalogProvider.notifier).setCurrentBannerIndex(index);
                                  },
                                  onLocationTap: _showLocationBottomSheet,
                                  onOpenSearch: _openSearch,
                                  searchBar: _buildSingleSearchBox(isFloating: false),
                                  onRefresh: _fetchData,
                                ),
                              ),
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
}

/// Retain alias for backward compatibility
typedef GroceryHomePage = HomePage;
