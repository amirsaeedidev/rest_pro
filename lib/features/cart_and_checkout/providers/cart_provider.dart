import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/model/product_model.dart';
import '../../../core/model/cart_item_model.dart';
import '../../../core/services/product_service.dart';

class CartPriceChange {
  const CartPriceChange({
    required this.productId,
    required this.productName,
    required this.previousPrice,
    required this.currentPrice,
  });

  final String productId;
  final String productName;
  final int previousPrice;
  final int currentPrice;
}

class CartProvider extends ChangeNotifier {
  static const _keyCart = 'cart_items';
  final List<CartItemModel> _items = [];
  final Map<String, ProductModel> _latestProducts = <String, ProductModel>{};
  final Map<String, CartPriceChange> _priceChanges = <String, CartPriceChange>{};
  StreamSubscription<List<ProductModel>>? _productsSubscription;

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, e) => sum + e.quantity);
  int get totalPrice => _items.fold(0, (sum, e) => sum + e.totalPrice);

  ProductModel? latestProduct(String productId) => _latestProducts[productId];
  List<CartPriceChange> get priceChanges =>
      List.unmodifiable(_priceChanges.values);
  List<CartItemModel> get unavailableItems => _items
      .where((item) => !item.product.isActive || !item.product.isAvailable)
      .toList(growable: false);

  bool isInCart(String productId) =>
      _items.any((e) => e.product.id == productId);

  int quantityOf(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    return index == -1 ? 0 : _items[index].quantity;
  }

  String noteOf(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    return index == -1 ? '' : _items[index].note;
  }

  CartProvider() {
    _loadCartFromPrefs();
    _productsSubscription = ProductService.watchProducts().listen(
      _syncProductSnapshots,
      onError: (Object error) => debugPrint('Cart product realtime sync failed: $error'),
    );
  }

  void _syncProductSnapshots(List<ProductModel> products) {
    _latestProducts
      ..clear()
      ..addEntries(products.map((product) => MapEntry(product.id, product)));
    _applyLatestProductsToCart();
  }

  void _applyLatestProductsToCart() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final current = _items[i].product;
      final latest = _latestProducts[current.id];
      final next = latest ?? current.copyWith(isActive: false, isAvailable: false);
      final item = _items[i];
      if (latest != null && latest.price != item.snapshotPrice) {
        _priceChanges[current.id] = CartPriceChange(
          productId: current.id,
          productName: latest.name,
          previousPrice: item.snapshotPrice,
          currentPrice: latest.price,
        );
      } else {
        _priceChanges.remove(current.id);
      }
      if (next != current) {
        _items[i] = item.copyWith(product: next);
        changed = true;
      }
    }
    if (changed) {
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  /// Re-checks cart prices and availability against Supabase before checkout.
  Future<void> refreshCartFromServer() async {
    if (_items.isEmpty) return;
    try {
      final products = await ProductService.getProductsByIds(
        _items.map((item) => item.product.id).toList(growable: false),
      );
      _syncProductSnapshots(products);
    } catch (error) {
      debugPrint('Refreshing cart from Supabase failed: $error');
    }
  }

  /// Accepts the newly fetched server prices after the customer has been warned.
  void acceptPriceChanges() {
    if (_priceChanges.isEmpty) return;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      _items[i] = item.copyWith(
        snapshotName: item.product.name,
        snapshotPrice: item.product.price,
      );
    }
    _priceChanges.clear();
    _saveCartToPrefs();
    notifyListeners();
  }

  // بارگذاری سبد خرید از حافظه محلی
  Future<void> _loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCart);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _items.clear();
        _items.addAll(list.map((e) => CartItemModel.fromJson(e)).toList());
        _applyLatestProductsToCart();
        notifyListeners();
        await refreshCartFromServer();
      }
    } catch (e) {
      print("Error loading cart: $e");
    }
  }

  // ذخیره سبد خرید در حافظه محلی
  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
      await prefs.setString(_keyCart, raw);
    } catch (e) {
      print("Error saving cart: $e");
    }
  }

  bool addItem(ProductModel product, {int quantity = 1, String note = ''}) {
    final latest = _latestProducts[product.id] ?? product;
    if (!latest.isActive || !latest.isAvailable || quantity < 1) return false;
    final index = _items.indexWhere((e) => e.product.id == latest.id);
    if (index == -1) {
      _items.add(CartItemModel(product: latest, quantity: quantity, note: note));
    } else {
      _items[index].quantity += quantity;
      if (note.isNotEmpty) _items[index].note = note;
    }
    _saveCartToPrefs();
    notifyListeners();
    return true;
  }

  void increment(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index != -1 && _items[index].product.isActive && _items[index].product.isAvailable) {
      _items[index].quantity++;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void decrement(String productId) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((e) => e.product.id == productId);
    _priceChanges.remove(productId);
    _saveCartToPrefs();
    notifyListeners();
  }

  void updateNote(String productId, String note) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index != -1) {
      _items[index].note = note;
      _saveCartToPrefs();
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _priceChanges.clear();
    _saveCartToPrefs();
    notifyListeners();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }
}