import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/supabase_service.dart';

enum AuthStatus {
  unknown,
  unauthenticated,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  static const _keyIsLoggedIn = 'isLoggedIn';
  static const _keyPhone = 'userPhone';
  static const bool _devPhoneLoginEnabled = bool.fromEnvironment(
    'DEV_PHONE_LOGIN_ENABLED',
    defaultValue: false,
  );

  AuthStatus _status = AuthStatus.unknown;
  String _phone = '';
  bool _isLoading = false;
  String? _error;
  String? _userId;

  AuthStatus get status => _status;
  String get phone => _phone;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool get _canUseDevelopmentLogin =>
      kDebugMode && _devPhoneLoginEnabled;

  AuthProvider() {
    _checkLoginStatus();
  }

  String _normalizeIranPhone(String value) {
    final normalizedDigits = value
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    var digits = normalizedDigits.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('0098')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '98${digits.substring(1)}';
    } else if (digits.length == 10 && digits.startsWith('9')) {
      digits = '98$digits';
    }

    return digits;
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _phone = prefs.getString(_keyPhone) ?? '';

      final session = SupabaseService.client.auth.currentSession;
      final currentUser = SupabaseService.client.auth.currentUser;

      if (session != null && currentUser != null) {
        _userId = currentUser.id;
        _status = AuthStatus.authenticated;
      } else {
        await prefs.remove(_keyIsLoggedIn);
        _userId = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (error) {
      debugPrint('AUTH CHECK FAILED: $error');
      _status = AuthStatus.unauthenticated;
      _userId = null;
    }

    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_canUseDevelopmentLogin) {
        _error = 'ورود آزمایشی فقط در نسخه Debug و با فعال‌سازی توسعه در زمان اجرا مجاز است.';
        return false;
      }

      final normalizedPhone = _normalizeIranPhone(phone);
      if (!RegExp(r'^989[0-9]{9}$').hasMatch(normalizedPhone)) {
        _error = 'شماره موبایل معتبر نیست';
        return false;
      }

      _phone = normalizedPhone;
      return true;
    } catch (error) {
      debugPrint('DEV LOGIN PREPARATION FAILED: $error');
      _error = 'آماده‌سازی ورود آزمایشی ناموفق بود';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (!_canUseDevelopmentLogin) {
        _error = 'ورود آزمایشی در این نسخه غیرفعال است';
        return false;
      }

      if (_phone.isEmpty) {
        _error = 'ابتدا شماره موبایل را وارد کنید';
        return false;
      }

      if (!RegExp(r'^[0-9]{4,8}$').hasMatch(code.trim())) {
        _error = 'کد تأیید معتبر نیست';
        return false;
      }

      final response = await SupabaseService.client.functions.invoke(
        'dev-phone-login',
        body: {
          'phone': _phone,
          'code': code.trim(),
        },
      );

      final payload = Map<String, dynamic>.from(response.data as Map);
      final refreshToken = payload['refresh_token'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        throw StateError('پاسخ ورود آزمایشی ناقص است');
      }

      final authResponse =
          await SupabaseService.client.auth.setSession(refreshToken);
      final user = authResponse.user;
      final session = authResponse.session;

      if (user == null || session == null) {
        throw StateError('نشست معتبر Supabase دریافت نشد');
      }

      _userId = user.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyPhone, _phone);
      _status = AuthStatus.authenticated;
      return true;
    } catch (error) {
      debugPrint('DEV PHONE LOGIN FAILED: $error');
      _error = 'ورود انجام نشد. شماره مجاز، کد تست و تنظیمات سرور را بررسی کنید.';
      _status = AuthStatus.unauthenticated;
      _userId = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyPhone);
      await SupabaseService.client.auth.signOut();

      _status = AuthStatus.unauthenticated;
      _phone = '';
      _userId = null;
      _error = null;
    } catch (error) {
      debugPrint('SIGN OUT FAILED: $error');
    }

    notifyListeners();
  }
}
