import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/model/cart_item_model.dart';
import '../../../core/model/order_model.dart';
import '../../../core/services/supabase_service.dart';

class OrdersProvider extends ChangeNotifier {
  List<OrderModel> _orders = const [];
  bool _isLoading = false;
  String? _error;
  String? _activeUserId;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  int _fetchGeneration = 0;
  String? _pendingOrderRequestId;
  String? _pendingOrderFingerprint;
  static const _pendingRequestIdKey = 'pending_order_request_id';
  static const _pendingRequestFingerprintKey = 'pending_order_request_fingerprint';

  OrdersProvider() {
    // This provider is created before mock login. Refresh when the isolated
    // anonymous Supabase guest session is created or restored.
    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((_) {
      if (!_mounted) return;
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        _fetchGeneration++;
        _ordersSubscription?.cancel();
        _ordersSubscription = null;
        _activeUserId = null;
        _orders = const [];
        _error = null;
        _isLoading = false;
        notifyListeners();
      } else if (_activeUserId != userId) {
        _ordersSubscription?.cancel();
        _ordersSubscription = null;
        _activeUserId = null;
        _orders = const [];
        _error = null;
        fetchOrders();
      }
    });
  }

  List<OrderModel> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrderModel> get activeOrders => _orders
      .where((order) =>
          order.status != OrderStatus.delivered &&
          order.status != OrderStatus.cancelled)
      .toList(growable: false);

  List<OrderModel> get historyOrders => _orders
      .where((order) =>
          order.status == OrderStatus.delivered ||
          order.status == OrderStatus.cancelled)
      .toList(growable: false);

  Future<void> fetchOrders() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      _fetchGeneration++;
      _ordersSubscription?.cancel();
      _ordersSubscription = null;
      _activeUserId = null;
      _orders = const [];
      _error = 'برای مشاهده سفارش‌ها وارد حساب شوید.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    final generation = ++_fetchGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.client
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      final mappedOrders = await _mapOrdersWithItems(rows);
      if (generation != _fetchGeneration || isDisposed) return;

      _orders = mappedOrders;
      _activeUserId = userId;
      _subscribeToOrderChanges(userId);
    } catch (error, stackTrace) {
      debugPrint('Fetch customer orders failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _error = 'دریافت سفارش‌ها ناموفق بود. دوباره تلاش کنید.';
    } finally {
      if (generation == _fetchGeneration && !isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool get isDisposed => !_mounted;
  bool _mounted = true;

  void _subscribeToOrderChanges(String userId) {
    if (_activeUserId == userId && _ordersSubscription != null) return;
    _activeUserId = userId;
    _ordersSubscription?.cancel();
    _ordersSubscription = SupabaseService.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .listen(
      (rows) async {
        try {
          final previousItems = <String, List<OrderItemModel>>{
            for (final order in _orders)
              if (order.items.isNotEmpty) order.id: order.items,
          };
          final mapped = await _mapOrdersWithItems(rows);
          if (!_mounted || _activeUserId != userId) return;
          _orders = mapped
              .map((order) => order.items.isEmpty &&
                      previousItems.containsKey(order.id)
                  ? order.copyWith(items: previousItems[order.id])
                  : order)
              .toList(growable: false);
          _error = null;
          notifyListeners();
        } catch (error) {
          debugPrint('Realtime customer order update failed: $error');
        }
      },
      onError: (Object error) =>
          debugPrint('Customer orders realtime stream failed: $error'),
    );
  }

  Future<List<OrderModel>> _mapOrdersWithItems(
    List<Map<String, dynamic>> orderRows,
  ) async {
    final orders = orderRows.map(OrderModel.fromJson).toList(growable: false);
    if (orders.isEmpty) return const [];

    final orderIds = orders.map((order) => order.id).toList(growable: false);
    final itemsByOrderId = <String, List<OrderItemModel>>{};
    try {
      final itemRows = await SupabaseService.client
          .from('order_items')
          .select('order_id, product_id, product_name, quantity, unit_price, products(name)')
          .inFilter('order_id', orderIds);

      for (final rawRow in itemRows as List) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final productValue = row['products'];
        final product = productValue is Map
            ? Map<String, dynamic>.from(productValue)
            : const <String, dynamic>{};
        final orderId = row['order_id']?.toString() ?? '';
        if (orderId.isEmpty) continue;
        final item = OrderItemModel(
          productId: row['product_id']?.toString() ?? '',
          productName: row['product_name'] as String? ?? product['name'] as String? ?? 'محصول حذف‌شده',
          quantity: (row['quantity'] as num?)?.toInt() ?? 1,
          unitPrice: (row['unit_price'] as num?)?.round() ?? 0,
        );
        (itemsByOrderId[orderId] ??= <OrderItemModel>[]).add(item);
      }
    } catch (error) {
      // Keep the orders visible even when the item relation is temporarily unavailable.
      debugPrint('Could not load order items: $error');
    }

    return orders
        .map((order) => order.copyWith(
              items: itemsByOrderId[order.id] ?? const <OrderItemModel>[],
            ))
        .toList(growable: false);
  }

  OrderModel? findById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Persists the order through the CRM's transactional RPC.
  /// The customer-facing payment step remains simulated; no payment provider is called.
  Future<bool> placeOrder(
    OrderModel order,
    List<CartItemModel> cartItems,
    String? discountCode,
  ) async {
    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      _error = 'برای ثبت سفارش وارد حساب شوید.';
      notifyListeners();
      return false;
    }
    if (cartItems.isEmpty) {
      _error = 'سبد خرید خالی است.';
      notifyListeners();
      return false;
    }

    try {
      final itemsPayload = cartItems
          .map((item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              })
          .toList(growable: false);

      final orderType = order.type == OrderType.delivery
          ? 'delivery'
          : (order.type == OrderType.pickup ? 'pickup' : 'dine_in');
      final fingerprint = jsonEncode({
        'user_id': userId,
        'order_type': orderType,
        'items': itemsPayload,
        'address_id': order.addressId,
        'address_line': order.address,
        'table_number': order.tableNumber,
        'table_id': order.tableId,
        'note': order.note,
        'discount_code': discountCode,
      });
      final prefs = await SharedPreferences.getInstance();
      _pendingOrderRequestId ??= prefs.getString(_pendingRequestIdKey);
      _pendingOrderFingerprint ??= prefs.getString(_pendingRequestFingerprintKey);
      if (_pendingOrderFingerprint != fingerprint || _pendingOrderRequestId == null) {
        _pendingOrderFingerprint = fingerprint;
        _pendingOrderRequestId = const Uuid().v4();
        await prefs.setString(_pendingRequestFingerprintKey, fingerprint);
        await prefs.setString(_pendingRequestIdKey, _pendingOrderRequestId!);
      }

      final response = await client.rpc(
        'place_order_idempotent',
        params: {
          'p_client_request_id': _pendingOrderRequestId,
          'p_order_type': orderType,
          'p_items': itemsPayload,
          'p_address_id': order.addressId,
          'p_address_line': order.address,
          'p_table_number': order.tableNumber,
          'p_table_id': order.tableId,
          'p_note': order.note,
          'p_discount_code': discountCode,
        },
      );

      // The live Supabase RPC returns the new order UUID, not an order JSON row.
      final orderId = response?.toString() ?? '';
      if (orderId.isEmpty) {
        throw const FormatException('place_order_idempotent did not return an order id');
      }

      var savedOrder = order.copyWith(
        id: orderId,
        orderCode: orderId.length >= 8
            ? orderId.substring(0, 8).toUpperCase()
            : orderId.toUpperCase(),
        items: cartItems
            .map((item) => OrderItemModel(
                  productId: item.product.id,
                  productName: item.product.name,
                  quantity: item.quantity,
                  unitPrice: item.product.price,
                ))
            .toList(growable: false),
      );

      // Read authoritative order totals and immutable item snapshots saved by the RPC.
      try {
        final responses = await Future.wait<dynamic>([
          client.from('orders').select().eq('id', orderId).single(),
          client
              .from('order_items')
              .select('order_id, product_id, product_name, quantity, unit_price')
              .eq('order_id', orderId),
        ]);
        final row = Map<String, dynamic>.from(responses[0] as Map);
        final itemRows = (responses[1] as List)
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .toList(growable: false);
        final snapshotItems = itemRows
            .map((item) => OrderItemModel(
                  productId: item['product_id']?.toString() ?? '',
                  productName: item['product_name']?.toString() ?? 'محصول حذف‌شده',
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  unitPrice: (item['unit_price'] as num?)?.round() ?? 0,
                ))
            .toList(growable: false);
        savedOrder = OrderModel.fromJson(row).copyWith(items: snapshotItems);
      } catch (error) {
        debugPrint('Order created, but its authoritative snapshot could not be re-read: $error');
      }

      _upsertOrder(savedOrder);
      _pendingOrderRequestId = null;
      _pendingOrderFingerprint = null;
      await prefs.remove(_pendingRequestIdKey);
      await prefs.remove(_pendingRequestFingerprintKey);
      _error = null;
      if (_activeUserId != userId || _ordersSubscription == null) {
        _subscribeToOrderChanges(userId);
      }
      notifyListeners();
      return true;
    } catch (error, stackTrace) {
      final details = error.toString().toLowerCase();
      if (details.contains('invalid, expired, or ineligible discount code')) {
        _error = 'کد تخفیف نامعتبر، منقضی یا برای این حساب غیرمجاز است.';
      } else if (details.contains('product is unavailable')) {
        _error = 'یکی از محصولات دیگر در دسترس نیست. سبد خرید را تازه‌سازی کنید.';
      } else if (details.contains('authentication required')) {
        _error = 'نشست ورود معتبر نیست؛ دوباره وارد حساب آزمایشی شوید.';
      } else if (details.contains('delivery address is required')) {
        _error = 'برای سفارش دلیوری باید آدرس تحویل ثبت شود.';
      } else {
        _error = 'ثبت سفارش در سرور انجام نشد. اطلاعات سفارش و اتصال را بررسی کنید.';
      }
      debugPrint('Place order failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
      return false;
    }
  }

  void _upsertOrder(OrderModel order) {
    final index = _orders.indexWhere((existing) => existing.id == order.id);
    if (index == -1) {
      _orders = [order, ..._orders];
    } else {
      final updated = [..._orders];
      updated[index] = order;
      _orders = updated;
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _authSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
