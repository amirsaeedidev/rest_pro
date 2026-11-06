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
  static const _enableDevPhoneLogin = bool.fromEnvironment(
    'ENABLE_DEV_PHONE_LOGIN',
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

  AuthProvider() {
    _checkLoginStatus();
  }

  String? _normalizePhone(String input) {
    final persian = '۰۱۲۳۴۵۶۷۸۹';
    final arabic = '٠١٢٣٤٥٦٧٨٩';
    var value = input.trim();
    for (var i = 0; i < 10; i++) {
      value = value.replaceAll(persian[i], '$i');
      value = value.replaceAll(arabic[i], '$i');
    }
    value = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (value.startsWith('0098')) {
      value = value.substring(4);
    } else if (value.startsWith('98')) {
      value = value.substring(2);
    }
    if (value.length == 10 && value.startsWith('9')) {
      value = '0$value';
    }
    if (!RegExp(r'^09[0-9]{9}$').hasMatch(value)) {
      return null;
    }
    return value;
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _phone = prefs.getString(_keyPhone) ?? '';

      final auth = SupabaseService.client.auth;
      final currentUser = auth.currentUser;
      final session = auth.currentSession;

      // Sessions created by the old shared development account must not be
      // reused: every test phone now receives a separate Supabase identity.
      if (currentUser?.email == 'dev@restaurant.test') {
        await auth.signOut();
        await prefs.remove(_keyIsLoggedIn);
        await prefs.remove(_keyPhone);
        _phone = '';
        _userId = null;
        _status = AuthStatus.unauthenticated;
      } else if (session != null && currentUser != null) {
        _userId = currentUser.id;
        _status = AuthStatus.authenticated;
      } else {
        await prefs.remove(_keyIsLoggedIn);
        _userId = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (e, stackTrace) {
      debugPrint('AUTH CHECK ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
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
      final normalized = _normalizePhone(phone);
      if (normalized == null) {
        _error = 'شماره موبایل معتبر نیست';
        return false;
      }
      _phone = normalized;
      return true;
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
      if (!kDebugMode || !_enableDevPhoneLogin) {
        _error = 'ورود آزمایشی فقط در نسخه توسعه و با تنظیم ENABLE_DEV_PHONE_LOGIN فعال است';
        return false;
      }

      if (_phone.isEmpty) {
        _error = 'شماره موبایل وارد نشده است';
        return false;
      }
      if (code.trim().isEmpty) {
        _error = 'کد آزمایشی را وارد کنید';
        return false;
      }

      final auth = SupabaseService.client.auth;
      final currentUser = auth.currentUser;

      // The function accepts only an anonymous bootstrap session. It then
      // exchanges that short-lived identity for the phone-specific account.
      if (currentUser != null && currentUser.email != null) {
        await auth.signOut();
      }
      if (auth.currentSession == null) {
        await auth.signInAnonymously();
      }

      final response = await SupabaseService.client.functions.invoke(
        'dev-customer-login',
        body: {
          'phone': _phone,
          'code': code.trim(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw Exception('ورود آزمایشی از سمت سرور تأیید نشد');
      }

      final data = response.data;
      if (data is! Map || data['refresh_token'] is! String) {
        throw Exception('پاسخ احراز هویت سرور معتبر نیست');
      }

      final authResponse = await auth.setSession(data['refresh_token'] as String);
      final user = authResponse.user ?? auth.currentUser;
      final session = authResponse.session ?? auth.currentSession;
      if (user == null || session == null) {
        throw Exception('نشست اختصاصی مشتری ایجاد نشد');
      }

      _userId = user.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyPhone, _phone);
      _status = AuthStatus.authenticated;
      return true;
    } catch (e, stackTrace) {
      debugPrint('DEVELOPMENT LOGIN ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      _error = 'ورود انجام نشد؛ تنظیمات ورود توسعه و اتصال سرور را بررسی کنید';
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
    } catch (e, stackTrace) {
      debugPrint('SIGN OUT ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
    notifyListeners();
  }
}
