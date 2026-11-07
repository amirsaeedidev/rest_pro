import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/model/discount_model.dart';
import '../../../core/model/cart_item_model.dart';
import '../../../core/services/discount_service.dart';

/// وضعیت لودینگ Provider
enum DiscountLoadState { idle, loading, loaded, error }

class DiscountProvider extends ChangeNotifier {
  // ── State ──
  List<DiscountModel> _discounts = [];
  DiscountLoadState _loadState = DiscountLoadState.idle;
  String? _loadError;

  // ── برای checkout ──
  DiscountModel? _appliedDiscount;
  int _discountAmount = 0;
  bool _isApplying = false;
  String? _applyError;
  StreamSubscription<List<DiscountModel>>? _discountsSubscription;
  bool _disposed = false;
  Timer? _serverRefreshTimer;

  // ── Getters ──
  List<DiscountModel> get all => List.unmodifiable(_discounts);
  List<DiscountModel> get active =>
      _discounts.where((d) => d.isActive).toList();
  List<DiscountModel> get usedOrExpired =>
      _discounts.where((d) => !d.isActive).toList();

  DiscountLoadState get loadState => _loadState;
  bool get isLoading => _loadState == DiscountLoadState.loading;
  String? get loadError => _loadError;

  DiscountModel? get appliedDiscount => _appliedDiscount;
  int get discountAmount => _discountAmount;
  bool get isApplying => _isApplying;
  String? get applyError => _applyError;
  bool get hasDiscount => _appliedDiscount != null && _discountAmount > 0;

  // ────────────────────────────────────────────
  // بارگذاری تخفیف‌ها از Supabase
  // ────────────────────────────────────────────
  Future<void> loadDiscounts() async {
    if (_loadState == DiscountLoadState.loaded) return;

    _loadState = DiscountLoadState.loading;
    _loadError = null;
    notifyListeners();

    try {
      _discounts = await DiscountService.fetchAvailableDiscounts();
      _loadState = DiscountLoadState.loaded;
      _subscribeToDiscountChanges();
      _startServerRefresh();
    } catch (e) {
      _loadState = DiscountLoadState.error;
      _loadError = e.toString();
    }

    if (!_disposed) notifyListeners();
  }

  void _startServerRefresh() {
    _serverRefreshTimer ??= Timer.periodic(const Duration(minutes: 1), (_) async {
      if (_disposed) return;
      try {
        final latest = await DiscountService.fetchAvailableDiscounts();
        if (_disposed) return;
        _discounts = latest;
        _loadState = DiscountLoadState.loaded;
        _loadError = null;
        notifyListeners();
      } catch (error) {
        if (_disposed) return;
        _loadError = error.toString();
        notifyListeners();
      }
    });
  }

  void _subscribeToDiscountChanges() {
    if (_discountsSubscription != null || _disposed) return;
    _discountsSubscription = DiscountService.watchAvailableDiscounts().listen(
      (discounts) {
        if (_disposed) return;
        _discounts = discounts;
        _loadState = DiscountLoadState.loaded;
        _loadError = null;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed) return;
        _loadError = error.toString();
        // Keep the last good snapshot visible if Realtime disconnects.
        notifyListeners();
      },
    );
  }

  // ── force reload (برای pull-to-refresh) ──
  Future<void> reload() async {
    _loadState = DiscountLoadState.idle;
    await loadDiscounts();
  }

  // ────────────────────────────────────────────
  // اعمال کد تخفیف (Supabase)
  // ────────────────────────────────────────────
  Future<void> applyCode({
    required String code,
    required List<CartItemModel> items,
  }) async {
    if (code.trim().isEmpty) return;

    _isApplying = true;
    _applyError = null;
    notifyListeners();

    final result = await DiscountService.applyCode(
      code: code,
      items: items,
    );

    if (result.success) {
      _appliedDiscount = result.discount;
      _discountAmount = result.discountAmount;
      _applyError = null;
    } else {
      _appliedDiscount = null;
      _discountAmount = 0;
      _applyError = result.errorMessage;
    }

    _isApplying = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  // حذف کد اعمال‌شده
  // ────────────────────────────────────────────
  void removeDiscount() {
    _appliedDiscount = null;
    _discountAmount = 0;
    _applyError = null;
    notifyListeners();
  }

  // ────────────────────────────────────────────
  // علامت‌گذاری به‌عنوان استفاده‌شده (بعد از پرداخت)
  // ────────────────────────────────────────────
  /// Clears the local selection after the order RPC commits redemption.
  void clearAppliedAfterOrder() {
    removeDiscount();
  }

  // ── reset کامل (هنگام logout) ──
  void reset() {
    _serverRefreshTimer?.cancel();
    _serverRefreshTimer = null;
    _discountsSubscription?.cancel();
    _discountsSubscription = null;
    _discounts = [];
    _loadState = DiscountLoadState.idle;
    _loadError = null;
    _appliedDiscount = null;
    _discountAmount = 0;
    _applyError = null;
    _isApplying = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _serverRefreshTimer?.cancel();
    _discountsSubscription?.cancel();
    super.dispose();
  }
}