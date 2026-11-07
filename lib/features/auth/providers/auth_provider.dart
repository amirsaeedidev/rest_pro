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

  // This code only controls the mock UI flow. It is not an authentication
  // factor; Supabase Anonymous Auth provides the server-side identity.
  static const _mockOtpCode = String.fromEnvironment(
    'MOCK_LOGIN_CODE',
    defaultValue: '1234',
  );
  static const _legacySharedEmail = 'dev@restaurant.test';

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

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = SupabaseService.client.auth;
      final currentUser = auth.currentUser;
      final session = auth.currentSession;

      // Retire the legacy shared account. It must never be reused by customers.
      if (currentUser?.email == _legacySharedEmail) {
        await auth.signOut();
        await prefs.remove(_keyIsLoggedIn);
        await prefs.remove(_keyPhone);
        _phone = '';
        _userId = null;
        _status = AuthStatus.unauthenticated;
      } else if (session != null && currentUser != null) {
        _userId = currentUser.id;
        _phone = prefs.getString(_keyPhone) ?? '';
        _status = prefs.getBool(_keyIsLoggedIn) == true
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      } else {
        await prefs.remove(_keyIsLoggedIn);
        await prefs.remove(_keyPhone);
        _phone = '';
        _userId = null;
        _status = AuthStatus.unauthenticated;
      }
    } catch (error, stackTrace) {
      debugPrint('AUTH CHECK ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      _status = AuthStatus.unauthenticated;
      _userId = null;
    }
    notifyListeners();
  }

  /// Mock send step: no SMS provider or real OTP request is called.
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 350));
      _phone = phone.trim();
      if (_phone.isEmpty) {
        _error = 'شماره تلفن را وارد کنید';
        return false;
      }
      return true;
    } catch (error) {
      debugPrint('MOCK LOGIN SEND STEP FAILED: $error');
      _error = 'خطا در ادامه فرایند ورود آزمایشی';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Keeps the existing mock OTP screen, but creates/reuses one isolated
  /// anonymous Supabase identity for this app installation.
  Future<bool> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (code.trim() != _mockOtpCode) {
        _error = 'کد وارد شده اشتباه است';
        return false;
      }
      if (_phone.trim().isEmpty) {
        _error = 'شماره تلفن وارد نشده است';
        return false;
      }

      final auth = SupabaseService.client.auth;
      if (auth.currentUser?.email == _legacySharedEmail) {
        await auth.signOut();
      }

      var user = auth.currentUser;
      var session = auth.currentSession;

      if (user == null || session == null) {
        final response = await auth.signInAnonymously();
        user = response.user;
        session = response.session;
      }

      if (user == null || session == null) {
        throw StateError('Supabase guest identity/session was not created.');
      }

      _userId = user.id;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyPhone, _phone);

      _status = AuthStatus.authenticated;
      return true;
    } catch (error, stackTrace) {
      debugPrint('MOCK GUEST LOGIN FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
      _error = 'ورود آزمایشی انجام نشد. تنظیم Anonymous Auth و اتصال را بررسی کنید.';
      _status = AuthStatus.unauthenticated;
      _userId = SupabaseService.client.auth.currentUser?.id;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// UI logout only. Keep the anonymous Supabase session on this installation
  /// so existing orders, wallet and loyalty data remain attached to its UID.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyPhone);

      _status = AuthStatus.unauthenticated;
      _phone = '';
      _userId = SupabaseService.client.auth.currentUser?.id;
      _error = null;
    } catch (error, stackTrace) {
      debugPrint('MOCK UI SIGN OUT FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    notifyListeners();
  }
}
