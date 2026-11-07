import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/model/loyalty_model.dart';
import '../../../core/services/supabase_service.dart';

class LoyaltyProvider extends ChangeNotifier {
  int _points = 0;
  bool _isLoading = false;
  bool _loaded = false;
  bool _disposed = false;
  String? _activeUserId;
  int _fetchGeneration = 0;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _walletSubscription;

  int get points => _points;
  bool get isLoading => _isLoading;
  bool get loaded => _loaded;

  LevelConfig get currentLevel => levelOf(_points);
  LevelConfig get nextLevel =>
      currentLevel.level == MemberLevel.vip ? currentLevel : levels[1];

  // پیشرفت تا سطح بعدی (0.0 تا 1.0)
  double get progress {
    if (currentLevel.level == MemberLevel.vip) return 1.0;
    return (_points / nextLevel.minPoints).clamp(0.0, 1.0);
  }

  // چند امتیاز تا VIP مانده
  int get pointsToNextLevel =>
      currentLevel.level == MemberLevel.vip
          ? 0
          : nextLevel.minPoints - _points;

  // قالب‌بندی عدد با هزارگان
  String formatPoints(int p) {
    final s = p.toString();
    final buf = StringBuffer();
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  LoyaltyProvider() {
    // This provider is created before the mock OTP flow signs into the test user.
    // Refresh the wallet when the existing Supabase auth session changes.
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((_) {
      fetchPoints();
    });
  }

  // دریافت امتیازات از Supabase
  Future<void> fetchPoints() async {
    if (_disposed) return;
    final generation = ++_fetchGeneration;
    _isLoading = true;
    notifyListeners();

    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (generation != _fetchGeneration || _disposed) return;
      if (userId == null) {
        _points = 0;
        _loaded = true;
        _activeUserId = null;
        await _walletSubscription?.cancel();
        _walletSubscription = null;
        return;
      }

      final response = await SupabaseService.client
          .from('loyalty_wallets')
          .select('total_points')
          .eq('user_identifier', userId)
          .maybeSingle();
      if (generation != _fetchGeneration || _disposed) return;

      _points = _parsePoints(response?['total_points']);
      _loaded = true;
      _activeUserId = userId;
      _subscribeToWallet(userId);
    } catch (error) {
      if (generation == _fetchGeneration && !_disposed) {
        debugPrint('Fetch loyalty points failed: $error');
        _loaded = true;
      }
    } finally {
      if (generation == _fetchGeneration && !_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _subscribeToWallet(String userId) {
    if (_disposed ||
        (_activeUserId == userId && _walletSubscription != null)) {
      return;
    }
    _activeUserId = userId;
    _walletSubscription?.cancel();
    _walletSubscription = SupabaseService.client
        .from('loyalty_wallets')
        .stream(primaryKey: ['id'])
        .eq('user_identifier', userId)
        .listen(
      (rows) {
        if (_disposed || _activeUserId != userId) return;
        _points = rows.isEmpty ? 0 : _parsePoints(rows.first['total_points']);
        _loaded = true;
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Loyalty realtime error: $error'),
    );
  }

  static int _parsePoints(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // reset برای تست
  Future<void> resetPoints() async {
    _points = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _fetchGeneration++;
    _authSubscription?.cancel();
    _walletSubscription?.cancel();
    super.dispose();
  }
}