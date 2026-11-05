import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/model/user_model.dart';
import '../../../core/services/supabase_service.dart';

class ProfileProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _disposed = false;
  String? _error;
  String? _activeUserId;
  StreamSubscription<List<Map<String, dynamic>>>? _profileSubscription;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  ProfileProvider() {
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    if (_disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        _user = null;
        _activeUserId = null;
        await _profileSubscription?.cancel();
        _profileSubscription = null;
        return;
      }

      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (_disposed) return;
      _user = response == null
          ? null
          : UserModel.fromJson(Map<String, dynamic>.from(response));
      _activeUserId = userId;
      _subscribeToProfileChanges(userId);
    } catch (error) {
      _error = 'خطا در دریافت اطلاعات کاربر';
      debugPrint('Fetch profile failed: $error');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToProfileChanges(String userId) {
    if (_disposed ||
        (_activeUserId == userId && _profileSubscription != null)) {
      return;
    }
    _activeUserId = userId;
    _profileSubscription?.cancel();
    _profileSubscription = SupabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen(
      (rows) {
        if (_disposed || _activeUserId != userId) return;
        _user = rows.isEmpty ? null : UserModel.fromJson(rows.first);
        _error = null;
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Profile realtime error: $error'),
    );
  }

  Future<bool> updateUser({String? firstName, String? lastName}) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return false;

    final payload = <String, dynamic>{};
    if (firstName != null) payload['first_name'] = firstName.trim();
    if (lastName != null) payload['last_name'] = lastName.trim();
    if (payload.isEmpty) return true;

    try {
      final updatedRow = await SupabaseService.client
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select('id')
          .maybeSingle();
      if (updatedRow == null) {
        _error = 'پروفایل قابل ویرایش نیست یا دسترسی لازم وجود ندارد';
        notifyListeners();
        return false;
      }

      _user = _user?.copyWith(
        firstName: firstName?.trim(),
        lastName: lastName?.trim(),
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'خطا در به‌روزرسانی پروفایل';
      debugPrint('Update profile failed: $error');
      notifyListeners();
      return false;
    }
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
    _user = null;
    _activeUserId = null;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profileSubscription?.cancel();
    super.dispose();
  }
}
