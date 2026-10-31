import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';

class UserRepository {
  static const String _kCachedAddressesKey = 'cached_user_addresses';
  static const String _kPendingDeletionsKey = 'pending_address_deletions';
  static const String _kSelectedAddressKey = 'selected_delivery_address';
  static const String _kUserLocationKey = 'user_location';

  // ─────────────────────────────────────────────────────────────────────────────
  // Local Address Cache & Selection
  // ─────────────────────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>>? _inMemoryAddresses;

  /// Synchronously returns in-memory addresses if available (0ms lag).
  List<Map<String, dynamic>> getInMemoryAddresses() {
    return _inMemoryAddresses != null ? List<Map<String, dynamic>>.from(_inMemoryAddresses!) : [];
  }

  /// Reads cached addresses from memory or device local storage.
  Future<List<Map<String, dynamic>>> getCachedAddresses() async {
    if (_inMemoryAddresses != null) {
      return List<Map<String, dynamic>>.from(_inMemoryAddresses!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedAddressesKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        final result = list.map((item) => Map<String, dynamic>.from(item)).toList();
        _inMemoryAddresses = result;
        return List<Map<String, dynamic>>.from(result);
      }
    } catch (e) {
      debugPrint('[UserRepository] Error reading cached addresses: $e');
    }
    return [];
  }

  /// Checks if address cache key exists in device storage (even if empty list).
  Future<bool> hasAddressCache() async {
    if (_inMemoryAddresses != null) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_kCachedAddressesKey);
    } catch (_) {
      return false;
    }
  }

  /// Writes addresses to device local storage cache.
  Future<void> saveCachedAddresses(List<dynamic> addresses) async {
    _inMemoryAddresses = addresses.map((item) => Map<String, dynamic>.from(item)).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedAddressesKey, jsonEncode(addresses));
    } catch (e) {
      debugPrint('[UserRepository] Error saving cached addresses: $e');
    }
  }

  /// Persists selected delivery address locally for instant offline usage.
  Future<void> setSelectedAddress(Map<String, dynamic> address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSelectedAddressKey, jsonEncode(address));
      final street = address['street']?.toString() ?? '';
      if (street.isNotEmpty) {
        await prefs.setString(_kUserLocationKey, street);
      }
    } catch (e) {
      debugPrint('[UserRepository] Error saving selected address: $e');
    }
  }

  /// Retrieves currently selected delivery address from device storage.
  Future<Map<String, dynamic>?> getSelectedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSelectedAddressKey);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw));
      }
    } catch (e) {
      debugPrint('[UserRepository] Error reading selected address: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Offline Deletion Sync Queue
  // ─────────────────────────────────────────────────────────────────────────────

  /// Gets list of address IDs scheduled to be deleted from server DB.
  Future<List<String>> getPendingDeletions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_kPendingDeletionsKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Queues an address ID to be deleted from DB when back online.
  Future<void> queuePendingDeletion(String addressId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPendingDeletionsKey) ?? [];
      if (!list.contains(addressId)) {
        list.add(addressId);
        await prefs.setStringList(_kPendingDeletionsKey, list);
        debugPrint('[UserRepository] Queued address $addressId for offline DB deletion.');
      }
    } catch (e) {
      debugPrint('[UserRepository] Error queueing deletion: $e');
    }
  }

  /// Automatically synchronizes and drains the pending offline deletion queue with DB.
  Future<void> syncPendingDeletions(Map<String, String> headers) async {
    try {
      final pending = await getPendingDeletions();
      if (pending.isEmpty) return;

      debugPrint('[UserRepository] Syncing ${pending.length} pending offline address deletion(s) with DB...');
      final remaining = <String>[];

      for (final id in pending) {
        try {
          final response = await http.delete(
            Uri.parse('${AppConfig.apiUrl}/addresses?id=$id'),
            headers: headers,
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 || response.statusCode == 404) {
            debugPrint('[UserRepository] Successfully deleted pending address $id from server DB.');
          } else {
            // Keep in queue if server temporarily errored
            remaining.add(id);
          }
        } catch (_) {
          // Still offline or timeout
          remaining.add(id);
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPendingDeletionsKey, remaining);
    } catch (e) {
      debugPrint('[UserRepository] Error during syncPendingDeletions: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // User Profile & Stats
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    final response = await http.get(Uri.parse('${AppConfig.apiUrl}/profile?user_id=$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? {};
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchMyProfile(Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/profile'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] is Map<String, dynamic> ? data['data'] : data;
      }
    } catch (e) {
      debugPrint('[UserRepository] fetchMyProfile error: $e');
    }
    return {};
  }

  static const String _kCachedUserStatsKey = 'cached_user_stats';

  Future<Map<String, dynamic>?> getCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCachedUserStatsKey);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw));
      }
    } catch (e) {
      debugPrint('[UserRepository] Error reading cached stats: $e');
    }
    return null;
  }

  Future<void> saveCachedStats(Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedUserStatsKey, jsonEncode(stats));
    } catch (e) {
      debugPrint('[UserRepository] Error saving cached stats: $e');
    }
  }

  Future<Map<String, dynamic>> fetchStats(Map<String, String> headers) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/profile/stats'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final result = data['data'] is Map<String, dynamic> ? data['data'] : data;
          await saveCachedStats(result);
          return result;
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] fetchStats error: $e');
    }
    final cached = await getCachedStats();
    if (cached != null && cached.isNotEmpty) return cached;
    return {};
  }

  Future<bool> updateProfile(Map<String, String> headers, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/profile'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      final resData = jsonDecode(response.body);
      return resData['success'] == true;
    }
    return false;
  }

  Future<String?> uploadAvatar(Map<String, String> headers, Uint8List imageBytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('${AppConfig.apiUrl}/profile/avatar'));
    request.headers.addAll(headers);
    final ext = filename.toLowerCase().split('.').last;
    final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: filename,
      contentType: MediaType('image', subType),
    ));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data']['url'];
      }
    } else {
      debugPrint('[uploadAvatar] failed: ${response.statusCode} ${response.body}');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Addresses CRUD (Cache-First + Optimistic Offline Sync)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Fetches addresses with offline fallback.
  /// First syncs any pending offline deletions with DB, fetches fresh data,
  /// caches on device, and falls back to cache if offline or slow.
  Future<List<dynamic>> fetchAddresses(Map<String, String> headers) async {
    // 1. Trigger background sync for pending offline deletions
    syncPendingDeletions(headers).ignore();

    // 2. Fetch fresh data from server
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/addresses'),
        headers: headers,
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List addrs = (data['addresses'] ?? data['data']?['addresses']) ?? [];
          
          // Exclude any addresses queued for offline deletion
          final pending = await getPendingDeletions();
          final filtered = addrs.where((a) => !pending.contains(a['id'])).toList();

          // Update local cache
          await saveCachedAddresses(filtered);
          return filtered;
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] fetchAddresses network issue / offline: $e');
    }

    // 3. Fallback to device cached addresses
    return await getCachedAddresses();
  }

  Future<bool> addAddress(Map<String, String> headers, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/addresses'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final newAddr = resData['data'] ?? resData['address'] ?? data;

        // Update local cache with newly created address
        final cached = await getCachedAddresses();
        if (newAddr is Map<String, dynamic> && newAddr.containsKey('id')) {
          if (newAddr['is_default'] == true) {
            for (var a in cached) {
              a['is_default'] = false;
            }
          }
          cached.insert(0, newAddr);
          await saveCachedAddresses(cached);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[UserRepository] Error adding address: $e');
    }
    return false;
  }

  Future<bool> updateAddress(Map<String, String> headers, String id, Map<String, dynamic> data) async {
    try {
      final bodyData = {...data, 'id': id};
      final response = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/addresses'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final updatedAddr = resData['data'] ?? resData['address'] ?? bodyData;

        // Update local cache
        final cached = await getCachedAddresses();
        final idx = cached.indexWhere((a) => a['id'] == id);
        if (idx != -1 && updatedAddr is Map<String, dynamic>) {
          cached[idx] = {...cached[idx], ...updatedAddr};
          await saveCachedAddresses(cached);
        }
        return true;
      }
    } catch (e) {
      debugPrint('[UserRepository] Error updating address: $e');
    }
    return false;
  }

  /// Optimistic delete:
  /// 1. Instantly deletes from phone's local cache.
  /// 2. Attempts DB deletion over network.
  /// 3. If user is offline or network fails, automatically queues the ID
  ///    in [pending_address_deletions] to delete from DB once online.
  Future<bool> deleteAddress(Map<String, String> headers, String id) async {
    // 1. Delete from local phone cache immediately
    try {
      final cached = await getCachedAddresses();
      final updated = cached.where((a) => a['id'] != id).toList();
      await saveCachedAddresses(updated);
    } catch (e) {
      debugPrint('[UserRepository] Error updating local cache on delete: $e');
    }

    // 2. Attempt network deletion
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/addresses?id=$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 || response.statusCode == 404) {
        debugPrint('[UserRepository] Address $id deleted from server DB immediately.');
        return true;
      } else {
        // Server returned temporary error -> schedule deletion
        await queuePendingDeletion(id);
        return true;
      }
    } catch (e) {
      // User is offline or request timed out -> queue for automatic sync when online
      debugPrint('[UserRepository] Network unavailable. Queued address $id for automatic DB deletion when online.');
      await queuePendingDeletion(id);
      return true;
    }
  }

  Future<List<dynamic>> fetchLeaderboard(
    Map<String, String> headers, {
    int limit = 50,
    int offset = 0,
    String? search,
    String? tier,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (tier != null && tier.isNotEmpty && tier != 'All') queryParams['tier'] = tier;

    final uri = Uri.parse('${AppConfig.apiUrl}/leaderboard').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['leaderboard'] ?? [];
      }
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Refer & Earn and Rewards System
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchReferralData(Map<String, String> headers) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/referrals'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? data;
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] fetchReferralData error: $e');
    }
    return {};
  }

  Future<bool> applyReferralCode(Map<String, String> headers, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/referrals'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('[UserRepository] applyReferralCode error: $e');
    }
    return false;
  }

  Future<List<dynamic>> fetchRewardItems() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/rewards'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['items'] ?? data['data']?['items'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] fetchRewardItems error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> redeemRewardItem(Map<String, String> headers, String rewardItemId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/rewards'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'rewardItemId': rewardItemId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[UserRepository] redeemRewardItem error: $e');
    }
    return null;
  }
}


