import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _timestamps = {};
  static SharedPreferences? _prefs;

  /// Initialize and preload common caches from disk
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final keys = _prefs?.getKeys() ?? {};
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          final cleanKey = key.replaceFirst('cache_', '');
          final raw = _prefs?.getString(key);
          if (raw != null) {
            try {
              final decoded = jsonDecode(raw);
              _memoryCache[cleanKey] = decoded;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[CacheService] Init error: $e');
    }
  }

  /// Synchronous instant 0ms memory cache read
  static T? get<T>(String key) {
    if (_memoryCache.containsKey(key)) {
      try {
        final val = _memoryCache[key];
        if (val is T) return val;
        if (T == List && val is List) return val as T;
        if (T == Map && val is Map) return val as T;
        return val as T;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Asynchronous disk read fallback if memory cache misses
  static Future<T?> getAsync<T>(String key) async {
    final mem = get<T>(key);
    if (mem != null) return mem;
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final raw = _prefs?.getString('cache_$key');
      if (raw != null) {
        final decoded = jsonDecode(raw);
        _memoryCache[key] = decoded;
        if (decoded is T) return decoded;
        if (T == List && decoded is List) return decoded as T;
        if (T == Map && decoded is Map) return decoded as T;
        return decoded as T?;
      }
    } catch (e) {
      debugPrint('[CacheService] getAsync error for $key: $e');
    }
    return null;
  }

  /// Write to instant memory and async commit to disk
  static Future<void> set(String key, dynamic data) async {
    _memoryCache[key] = data;
    _timestamps[key] = DateTime.now();

    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final encoded = jsonEncode(data);
      await _prefs?.setString('cache_$key', encoded);
    } catch (e) {
      debugPrint('[CacheService] set error for $key: $e');
    }
  }

  /// Checks if memory cache exists and isn't expired
  static bool isValid(String key, {Duration maxAge = const Duration(minutes: 30)}) {
    if (!_memoryCache.containsKey(key)) return false;
    final ts = _timestamps[key];
    if (ts == null) return true;
    return DateTime.now().difference(ts) < maxAge;
  }

  /// Invalidate specific key
  static Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _timestamps.remove(key);
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      await _prefs?.remove('cache_$key');
    } catch (_) {}
  }

  /// Clear all app caches
  static Future<void> clearAll() async {
    _memoryCache.clear();
    _timestamps.clear();
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      final keys = _prefs?.getKeys() ?? {};
      for (final k in keys) {
        if (k.startsWith('cache_')) {
          await _prefs?.remove(k);
        }
      }
    } catch (_) {}
  }
}
