import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/model/address_model.dart';
import '../../../core/services/supabase_service.dart';

class AddressProvider extends ChangeNotifier {
  List<AddressModel> _addresses = const [];
  bool _isLoading = false;
  bool _loaded = false;
  bool _disposed = false;
  String? _error;
  String? _activeUserId;
  int _fetchGeneration = 0;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _addressesSubscription;

  List<AddressModel> get addresses => List.unmodifiable(_addresses);
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;
  bool get isEmpty => _addresses.isEmpty;
  String? get error => _error;

  AddressModel? get defaultAddress {
    try {
      return _addresses.firstWhere((address) => address.isDefault);
    } catch (_) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  AddressProvider() {
    // The provider is constructed before the mock OTP flow finishes. Listen for
    // the resulting Supabase session rather than permanently caching a logged-out state.
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((_) {
      fetchAddresses();
    });
  }

  Future<void> fetchAddresses() async {
    if (_disposed) return;
    final generation = ++_fetchGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (generation != _fetchGeneration || _disposed) return;

      if (userId == null) {
        _addresses = const [];
        _loaded = true;
        _activeUserId = null;
        await _addressesSubscription?.cancel();
        _addressesSubscription = null;
        return;
      }

      final response = await SupabaseService.client
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (generation != _fetchGeneration || _disposed) return;
      _addresses = (response as List)
          .map((row) => AddressModel.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      _loaded = true;
      _activeUserId = userId;
      _subscribeToAddressChanges(userId);
    } catch (error) {
      if (generation == _fetchGeneration && !_disposed) {
        _error = 'خطا در دریافت آدرس‌ها';
        _loaded = true;
        debugPrint('Fetch addresses failed: $error');
      }
    } finally {
      if (generation == _fetchGeneration && !_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToAddressChanges(String userId) {
    if (_disposed ||
        (_activeUserId == userId && _addressesSubscription != null)) {
      return;
    }
    _activeUserId = userId;
    _addressesSubscription?.cancel();
    _addressesSubscription = SupabaseService.client
        .from('addresses')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen(
      (rows) {
        if (_disposed || _activeUserId != userId) return;
        _addresses = rows.map(AddressModel.fromJson).toList(growable: false);
        _loaded = true;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Addresses realtime error: $error'),
    );
  }

  Future<bool> add(AddressModel address) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) throw StateError('کاربر وارد نشده است');
      final payload = address.toJson();
      payload['user_id'] = userId;
      payload['is_default'] = _addresses.isEmpty;

      final response = await SupabaseService.client
          .from('addresses')
          .insert(payload)
          .select()
          .single();

      final saved = AddressModel.fromJson(Map<String, dynamic>.from(response));
      if (!_addresses.any((item) => item.id == saved.id)) {
        _addresses = [saved, ..._addresses];
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'خطا در ذخیره آدرس';
      debugPrint('Add address failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(AddressModel updated) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return false;
      await SupabaseService.client
          .from('addresses')
          .update(updated.toJson())
          .eq('id', updated.id)
          .eq('user_id', userId);

      _addresses = _addresses
          .map((address) => address.id == updated.id ? updated : address)
          .toList(growable: false);
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'خطا در ویرایش آدرس';
      debugPrint('Update address failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> remove(String id) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return false;
      final wasDefault = _addresses.any((address) => address.id == id && address.isDefault);
      await SupabaseService.client
          .from('addresses')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      _addresses = _addresses.where((address) => address.id != id).toList(growable: false);

      if (wasDefault && _addresses.isNotEmpty) {
        await setDefault(_addresses.first.id);
      }
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'خطا در حذف آدرس';
      debugPrint('Delete address failed: $error');
      notifyListeners();
      return false;
    }
  }

  Future<bool> setDefault(String id) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return false;

      final client = SupabaseService.client;
      await client.from('addresses').update({'is_default': false}).eq('user_id', userId);
      await client.from('addresses').update({'is_default': true}).eq('id', id).eq('user_id', userId);

      _addresses = _addresses
          .map((address) => address.copyWith(isDefault: address.id == id))
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'خطا در تنظیم آدرس پیش‌فرض';
      debugPrint('Set default address failed: $error');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _fetchGeneration++;
    _authSubscription?.cancel();
    _addressesSubscription?.cancel();
    super.dispose();
  }
}
