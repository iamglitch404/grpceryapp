import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CountryInfo {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;
  final int minLength;
  final int maxLength;
  final String sample;

  const CountryInfo({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.minLength,
    required this.maxLength,
    this.sample = '',
  });

  String get lengthDescription {
    if (minLength == maxLength) {
      return '$minLength digits';
    }
    return '$minLength-$maxLength digits';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'isoCode': isoCode,
        'dialCode': dialCode,
        'flag': flag,
        'minLength': minLength,
        'maxLength': maxLength,
        'sample': sample,
      };

  factory CountryInfo.fromJson(Map<String, dynamic> json) {
    return CountryInfo(
      name: json['name'] as String? ?? 'Nepal',
      isoCode: json['isoCode'] as String? ?? 'NP',
      dialCode: json['dialCode'] as String? ?? '+977',
      flag: json['flag'] as String? ?? '🇳🇵',
      minLength: json['minLength'] as int? ?? 10,
      maxLength: json['maxLength'] as int? ?? 10,
      sample: json['sample'] as String? ?? '9812345678',
    );
  }
}

/// Service providing IP-based country detection, persistent local caching to save requests,
/// and international digit limit definitions.
class CountryService {
  static const String _prefCountryIso = 'cached_user_country_iso';
  static const String _prefCountryDial = 'cached_user_country_dial';
  static const String _prefCountryName = 'cached_user_country_name';
  static const String _prefCountryFlag = 'cached_user_country_flag';
  static const String _prefCountryMin = 'cached_user_country_min';
  static const String _prefCountryMax = 'cached_user_country_max';
  static const String _prefCountrySample = 'cached_user_country_sample';
  static const String _prefUserIp = 'cached_user_ip';

  static CountryInfo? _cachedCountry;
  static String? _cachedIp;

  static const CountryInfo defaultCountry = CountryInfo(
    name: 'Nepal',
    isoCode: 'NP',
    dialCode: '+977',
    flag: '🇳🇵',
    minLength: 10,
    maxLength: 10,
    sample: '9812345678',
  );

  static CountryInfo getInitialCountry() {
    if (_cachedCountry != null) return _cachedCountry!;
    return defaultCountry;
  }

  static String? get cachedIp => _cachedIp;

  /// Loads the country code. First reads from SharedPreferences (0 network requests).
  /// If no cache exists, fetches IP and Country from IP Geolocation and saves it for future use.
  static Future<CountryInfo> getCountryWithIpFallback() async {
    if (_cachedCountry != null) return _cachedCountry!;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIso = prefs.getString(_prefCountryIso);
      _cachedIp = prefs.getString(_prefUserIp);

      if (savedIso != null && savedIso.isNotEmpty) {
        final matched = findByIso(savedIso);
        if (matched != null) {
          _cachedCountry = matched;
          return matched;
        }

        _cachedCountry = CountryInfo(
          name: prefs.getString(_prefCountryName) ?? 'Nepal',
          isoCode: savedIso,
          dialCode: prefs.getString(_prefCountryDial) ?? '+977',
          flag: prefs.getString(_prefCountryFlag) ?? '🇳🇵',
          minLength: prefs.getInt(_prefCountryMin) ?? 10,
          maxLength: prefs.getInt(_prefCountryMax) ?? 10,
          sample: prefs.getString(_prefCountrySample) ?? '9812345678',
        );
        return _cachedCountry!;
      }

      // No stored cache: Fetch from IP geolocation and cache
      return await detectAndCacheFromIp();
    } catch (e) {
      debugPrint('[CountryService] Error retrieving cached country: $e');
      return defaultCountry;
    }
  }

  /// Queries IP geolocation API, updates memory and persists in SharedPreferences to save future requests
  static Future<CountryInfo> detectAndCacheFromIp() async {
    try {
      final res = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final countryCode = data['country_code']?.toString().toUpperCase() ?? '';
          final callingCode = data['calling_code']?.toString() ?? '';
          final ip = data['ip']?.toString() ?? '';
          final countryName = data['country']?.toString() ?? '';
          final flagEmoji = data['flag']?['emoji']?.toString() ?? '';

          CountryInfo? matched = findByIso(countryCode);
          if (matched == null && callingCode.isNotEmpty) {
            matched = findByDialCode(callingCode.startsWith('+') ? callingCode : '+$callingCode');
          }

          final detectedCountry = matched ??
              CountryInfo(
                name: countryName.isNotEmpty ? countryName : 'International',
                isoCode: countryCode.isNotEmpty ? countryCode : 'INT',
                dialCode: callingCode.isNotEmpty
                    ? (callingCode.startsWith('+') ? callingCode : '+$callingCode')
                    : '+1',
                flag: flagEmoji.isNotEmpty ? flagEmoji : '🌐',
                minLength: 8,
                maxLength: 12,
                sample: '9812345678',
              );

          await saveCountryAndIp(detectedCountry, ip: ip);
          return detectedCountry;
        }
      }
    } catch (e) {
      debugPrint('[CountryService] ipwho.is detection failed: $e');
    }

    // Secondary fallback: ip-api.com
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json/'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          final code = data['countryCode']?.toString().toUpperCase() ?? '';
          final ip = data['query']?.toString() ?? '';
          final matched = findByIso(code);
          if (matched != null) {
            await saveCountryAndIp(matched, ip: ip);
            return matched;
          }
        }
      }
    } catch (e) {
      debugPrint('[CountryService] ip-api detection failed: $e');
    }

    return defaultCountry;
  }

  /// Persists country selection and IP to SharedPreferences to prevent repeated network calls
  static Future<void> saveCountryAndIp(CountryInfo country, {String? ip}) async {
    _cachedCountry = country;
    if (ip != null && ip.isNotEmpty) {
      _cachedIp = ip;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCountryIso, country.isoCode);
      await prefs.setString(_prefCountryDial, country.dialCode);
      await prefs.setString(_prefCountryName, country.name);
      await prefs.setString(_prefCountryFlag, country.flag);
      await prefs.setInt(_prefCountryMin, country.minLength);
      await prefs.setInt(_prefCountryMax, country.maxLength);
      await prefs.setString(_prefCountrySample, country.sample);
      if (ip != null && ip.isNotEmpty) {
        await prefs.setString(_prefUserIp, ip);
      }
    } catch (e) {
      debugPrint('[CountryService] Error saving country: $e');
    }
  }

  static CountryInfo? findByIso(String iso) {
    final cleanIso = iso.trim().toUpperCase();
    try {
      return countries.firstWhere((c) => c.isoCode.toUpperCase() == cleanIso);
    } catch (_) {
      return null;
    }
  }

  static CountryInfo? findByDialCode(String dial) {
    final clean = dial.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      return countries.firstWhere(
        (c) => c.dialCode == clean || c.dialCode == (clean.startsWith('+') ? clean : '+$clean'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Comprehensive list of international countries with standard phone digit lengths
  static const List<CountryInfo> countries = [
    CountryInfo(name: 'Nepal', isoCode: 'NP', dialCode: '+977', flag: '🇳🇵', minLength: 10, maxLength: 10, sample: '9812345678'),
    CountryInfo(name: 'India', isoCode: 'IN', dialCode: '+91', flag: '🇮🇳', minLength: 10, maxLength: 10, sample: '9876543210'),
    CountryInfo(name: 'United States', isoCode: 'US', dialCode: '+1', flag: '🇺🇸', minLength: 10, maxLength: 10, sample: '2025550123'),
    CountryInfo(name: 'United Kingdom', isoCode: 'GB', dialCode: '+44', flag: '🇬🇧', minLength: 10, maxLength: 10, sample: '7911123456'),
    CountryInfo(name: 'United Arab Emirates', isoCode: 'AE', dialCode: '+971', flag: '🇦🇪', minLength: 9, maxLength: 9, sample: '501234567'),
    CountryInfo(name: 'Australia', isoCode: 'AU', dialCode: '+61', flag: '🇦🇺', minLength: 9, maxLength: 9, sample: '412345678'),
    CountryInfo(name: 'Qatar', isoCode: 'QA', dialCode: '+974', flag: '🇶🇦', minLength: 8, maxLength: 8, sample: '33123456'),
    CountryInfo(name: 'Saudi Arabia', isoCode: 'SA', dialCode: '+966', flag: '🇸🇦', minLength: 9, maxLength: 9, sample: '501234567'),
    CountryInfo(name: 'Canada', isoCode: 'CA', dialCode: '+1', flag: '🇨🇦', minLength: 10, maxLength: 10, sample: '4165550123'),
    CountryInfo(name: 'Singapore', isoCode: 'SG', dialCode: '+65', flag: '🇸🇬', minLength: 8, maxLength: 8, sample: '81234567'),
    CountryInfo(name: 'Malaysia', isoCode: 'MY', dialCode: '+60', flag: '🇲🇾', minLength: 9, maxLength: 10, sample: '123456789'),
    CountryInfo(name: 'Japan', isoCode: 'JP', dialCode: '+81', flag: '🇯🇵', minLength: 10, maxLength: 10, sample: '9012345678'),
    CountryInfo(name: 'Germany', isoCode: 'DE', dialCode: '+49', flag: '🇩🇪', minLength: 10, maxLength: 11, sample: '15123456789'),
    CountryInfo(name: 'France', isoCode: 'FR', dialCode: '+33', flag: '🇫🇷', minLength: 9, maxLength: 9, sample: '612345678'),
    CountryInfo(name: 'Bangladesh', isoCode: 'BD', dialCode: '+880', flag: '🇧🇩', minLength: 10, maxLength: 10, sample: '1712345678'),
    CountryInfo(name: 'Pakistan', isoCode: 'PK', dialCode: '+92', flag: '🇵🇰', minLength: 10, maxLength: 10, sample: '3001234567'),
    CountryInfo(name: 'China', isoCode: 'CN', dialCode: '+86', flag: '🇨🇳', minLength: 11, maxLength: 11, sample: '13812345678'),
    CountryInfo(name: 'South Korea', isoCode: 'KR', dialCode: '+82', flag: '🇰🇷', minLength: 9, maxLength: 10, sample: '1012345678'),
    CountryInfo(name: 'Kuwait', isoCode: 'KW', dialCode: '+965', flag: '🇰🇼', minLength: 8, maxLength: 8, sample: '51234567'),
    CountryInfo(name: 'Bahrain', isoCode: 'BH', dialCode: '+973', flag: '🇧🇭', minLength: 8, maxLength: 8, sample: '36123456'),
    CountryInfo(name: 'Oman', isoCode: 'OM', dialCode: '+968', flag: '🇴🇲', minLength: 8, maxLength: 8, sample: '91234567'),
    CountryInfo(name: 'Philippines', isoCode: 'PH', dialCode: '+63', flag: '🇵🇭', minLength: 10, maxLength: 10, sample: '9171234567'),
    CountryInfo(name: 'Thailand', isoCode: 'TH', dialCode: '+66', flag: '🇹🇭', minLength: 9, maxLength: 9, sample: '812345678'),
    CountryInfo(name: 'New Zealand', isoCode: 'NZ', dialCode: '+64', flag: '🇳🇿', minLength: 8, maxLength: 10, sample: '211234567'),
    CountryInfo(name: 'Italy', isoCode: 'IT', dialCode: '+39', flag: '🇮🇹', minLength: 9, maxLength: 10, sample: '3201234567'),
    CountryInfo(name: 'Spain', isoCode: 'ES', dialCode: '+34', flag: '🇪🇸', minLength: 9, maxLength: 9, sample: '612345678'),
    CountryInfo(name: 'Netherlands', isoCode: 'NL', dialCode: '+31', flag: '🇳🇱', minLength: 9, maxLength: 9, sample: '612345678'),
    CountryInfo(name: 'Switzerland', isoCode: 'CH', dialCode: '+41', flag: '🇨🇭', minLength: 9, maxLength: 9, sample: '781234567'),
    CountryInfo(name: 'Sweden', isoCode: 'SE', dialCode: '+46', flag: '🇸🇪', minLength: 9, maxLength: 9, sample: '701234567'),
    CountryInfo(name: 'Norway', isoCode: 'NO', dialCode: '+47', flag: '🇳🇴', minLength: 8, maxLength: 8, sample: '41234567'),
    CountryInfo(name: 'Ireland', isoCode: 'IE', dialCode: '+353', flag: '🇮🇪', minLength: 9, maxLength: 9, sample: '851234567'),
    CountryInfo(name: 'South Africa', isoCode: 'ZA', dialCode: '+27', flag: '🇿🇦', minLength: 9, maxLength: 9, sample: '821234567'),
    CountryInfo(name: 'Turkey', isoCode: 'TR', dialCode: '+90', flag: '🇹🇷', minLength: 10, maxLength: 10, sample: '5321234567'),
    CountryInfo(name: 'Sri Lanka', isoCode: 'LK', dialCode: '+94', flag: '🇱🇰', minLength: 9, maxLength: 9, sample: '712345678'),
    CountryInfo(name: 'Maldives', isoCode: 'MV', dialCode: '+960', flag: '🇲🇻', minLength: 7, maxLength: 7, sample: '7912345'),
    CountryInfo(name: 'Bhutan', isoCode: 'BT', dialCode: '+975', flag: '🇧🇹', minLength: 8, maxLength: 8, sample: '17123456'),
    CountryInfo(name: 'Brazil', isoCode: 'BR', dialCode: '+55', flag: '🇧🇷', minLength: 10, maxLength: 11, sample: '11987654321'),
    CountryInfo(name: 'Indonesia', isoCode: 'ID', dialCode: '+62', flag: '🇮🇩', minLength: 9, maxLength: 12, sample: '8123456789'),
    CountryInfo(name: 'Vietnam', isoCode: 'VN', dialCode: '+84', flag: '🇻🇳', minLength: 9, maxLength: 10, sample: '912345678'),
  ];
}
