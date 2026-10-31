import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/customer/profile/presentation/pages/add_address_details_page.dart';

class LocationPickerPage extends StatefulWidget {
  final bool isAddingNewAddress;
  const LocationPickerPage({super.key, this.isAddingNewAddress = false});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController _mapController = MapController();
  LatLng _center = const LatLng(27.7172, 85.3240); // Default to Kathmandu, Nepal
  LatLng? _userLocation;
  bool _isLoading = false;
  String _currentAddress = "Kathmandu, Nepal";
  String _mainAddress = "Kathmandu";
  String _subAddress = "Bagmati Province, Nepal";
  Timer? _debounceTimer;
  Timer? _searchDebounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  String _currentMapLayer = 'standard';
  bool _isTrackingUser = false;
  bool _showLayerMenu = false;
  String _mapProvider = 'osm';
  bool _showProviderMenu = false;

  String _getMapUrl() {
    switch (_currentMapLayer) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'topo':
        return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'esri_street':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
      case 'standard':
      default:
        if (_mapProvider == 'hot') {
          return 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';
        } else if (_mapProvider == 'topo') {
          return 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png';
        }
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Widget _buildLayerOption(String label, String layerId) {
    final isSelected = _currentMapLayer == layerId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMapLayer = layerId;
          _showLayerMenu = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E523A) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderOption(String label, String providerId) {
    final isSelected = _mapProvider == providerId && _currentMapLayer == 'standard';
    return GestureDetector(
      onTap: () {
        setState(() {
          _mapProvider = providerId;
          _currentMapLayer = 'standard'; // Switch back to standard layer when changing provider
          _showProviderMenu = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF1E523A) : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // 1. Immediately reverse-geocode default/initial center so real address appears right away
    _fetchAddress(_center);
    // 2. Request precise GPS in parallel
    await _locateUserGPS(showError: false);
  }

  Future<void> _locateUserGPS({bool showError = true}) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (showError && mounted) {
        _showToast('Location services might be disabled.');
      }
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (showError && mounted) {
          _showToast('Location permissions are denied.');
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (showError && mounted) {
        _showToast('Location permissions are permanently denied.');
      }
      return;
    } 

    try {
      final Position position = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 10),
          );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _center = _userLocation!;
          _isTrackingUser = true;
        });
        _mapController.move(_center, 15.0);
        await _fetchAddress(_center);
      }
    } catch (e) {
      debugPrint("Error getting GPS location: $e");
      if (showError && mounted) {
        _showToast('Could not fetch exact location.');
      }
    }
  }

  Future<void> _fetchAddress(LatLng position) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'com.dovan.groceryapp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null && mounted) {
          final String displayName = data['display_name'];
          setState(() {
            _currentAddress = displayName;
            
            if (data['address'] != null) {
              final address = data['address'];
              final String? primary = address['road'] ?? 
                  address['suburb'] ?? 
                  address['neighbourhood'] ?? 
                  address['village'] ?? 
                  address['town'] ?? 
                  address['city'] ?? 
                  address['county'] ??
                  address['amenity'] ??
                  address['building'];
              
              if (primary != null && primary.isNotEmpty) {
                _mainAddress = primary;
              } else {
                _mainAddress = displayName.split(',').first.trim();
              }

              List<String> subParts = [];
              for (var part in displayName.split(',')) {
                final trimmed = part.trim();
                if (trimmed != _mainAddress && !subParts.contains(trimmed)) {
                  subParts.add(trimmed);
                }
              }
              _subAddress = subParts.take(3).join(', ');
              if (_subAddress.isEmpty) _subAddress = _currentAddress;
            } else {
              _mainAddress = displayName.split(',').first.trim();
              _subAddress = displayName;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching address: $e");
      if (mounted) {
         setState(() {
            _subAddress = "Could not fetch address details.";
         });
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5&countrycodes=np');
      final response = await http.get(url, headers: {'User-Agent': 'com.dovan.groceryapp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (mounted) {
          setState(() {
            _suggestions = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Suggestions fetch error: $e");
    }
    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(dynamic suggestion) {
    _searchFocusNode.unfocus();
    final lat = double.parse(suggestion['lat'].toString());
    final lon = double.parse(suggestion['lon'].toString());
    final newCenter = LatLng(lat, lon);
    
    setState(() {
      _searchController.text = suggestion['display_name'];
      _suggestions = [];
      _center = newCenter;
    });
    
    _mapController.move(newCenter, 15.0);
    _fetchAddress(newCenter);
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=np');
      final response = await http.get(url, headers: {'User-Agent': 'com.dovan.groceryapp'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          final newCenter = LatLng(lat, lon);
          if (mounted) {
            setState(() {
              _center = newCenter;
            });
            _mapController.move(newCenter, 15.0);
            _fetchAddress(newCenter);
          }
        } else {
          if (mounted) {
            _showToast('No places found for that search.');
          }
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        _showToast('Error searching for place.');
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveLocation() async {
    if (_mainAddress == "Please select delivery location" || _currentAddress == "Move map to select location") {
      if (mounted) {
        _showToast('Please move the map to select a valid location.');
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    // Combine them or just save the full string
    final finalAddress = "$_mainAddress, $_subAddress";
    await prefs.setString('user_location', finalAddress);
    
    if (mounted) {
      if (widget.isAddingNewAddress) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAddressDetailsPage(
              locationDetails: finalAddress,
              latitude: _center.latitude,
              longitude: _center.longitude,
            ),
          ),
        );
        if (result != null && mounted) {
          Navigator.pop(context, result);
        }
      } else {
        Navigator.pop(context, finalAddress);
      }
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_center, currentZoom + 1);
  }
  
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_center, currentZoom - 1);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0, // Zoomed in on Kathmandu initially
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  if (_isTrackingUser) {
                    setState(() => _isTrackingUser = false);
                  }
                  if (position.center != null) {
                    setState(() {
                      _center = position.center!;
                    });
                  }
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 600), () {
                    _fetchAddress(_center);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _getMapUrl(),
                userAgentPackageName: 'com.dovan.groceryapp',
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E523A).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E523A),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white,
                                  spreadRadius: 2.5,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          
          // Floating Search Bar & Suggestions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Bar
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _onSearchChanged,
                              decoration: const InputDecoration(
                                hintText: 'Search for area, street, or landmark',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 14),
                              ),
                              onSubmitted: _searchPlace,
                              textInputAction: TextInputAction.search,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (_isSearching)
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E523A))),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.search, color: Colors.grey, size: 20),
                            ),
                        ],
                      ),
                    ),
                    
                    // Suggestions Dropdown
                    if (_suggestions.isNotEmpty && _searchFocusNode.hasFocus) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.grey, size: 20),
                              title: Text(
                                suggestion['name'] ?? suggestion['display_name'].split(',').first,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                suggestion['display_name'],
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80.0), // Adjust for pin pointing to center
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    constraints: const BoxConstraints(maxWidth: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1E523A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Locating...',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E2022)),
                          ),
                        ] else ...[
                          const Icon(Icons.my_location_rounded, size: 13, color: Color(0xFF1E523A)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _mainAddress.isNotEmpty && _mainAddress != 'Please select delivery location'
                                  ? _mainAddress
                                  : 'Kathmandu, Nepal',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2022),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF1E523A),
                    size: 45,
                  ),
                ],
              ),
            ),
          ),
          
          // Zoom Controls
          Positioned(
            bottom: 220,
            right: 15,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_showProviderMenu) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProviderOption('1', 'cartodb'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildProviderOption('2', 'osm'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildProviderOption('3', 'light'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildProviderOption('4', 'hot'),
                          ],
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showProviderMenu = !_showProviderMenu;
                          if (_showProviderMenu) _showLayerMenu = false;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                        ),
                        child: Icon(Icons.public, color: _showProviderMenu ? const Color(0xFF1E523A) : Colors.black87, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_showLayerMenu) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLayerOption('1', 'standard'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildLayerOption('2', 'satellite'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildLayerOption('3', 'topo'),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            _buildLayerOption('4', 'esri_street'),
                          ],
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLayerMenu = !_showLayerMenu;
                          if (_showLayerMenu) _showProviderMenu = false;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                        ),
                        child: Icon(Icons.layers, color: _showLayerMenu ? const Color(0xFF1E523A) : Colors.black87, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => _locateUserGPS(showError: true),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                        ),
                        child: Icon(Icons.my_location, color: _isTrackingUser ? Colors.blue : Colors.black87, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _zoomIn,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                            ),
                            child: const Icon(Icons.add, color: Colors.black87),
                          ),
                        ),
                        Container(
                          height: 1,
                          width: 40,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                        GestureDetector(
                          onTap: _zoomOut,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5)],
                            ),
                            child: const Icon(Icons.remove, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Info Box
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF1E523A), size: 28),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mainAddress,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _subAddress,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            _searchFocusNode.requestFocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF1E523A)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(color: Color(0xFF1E523A), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E523A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Confirm this location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
