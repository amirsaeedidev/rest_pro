import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/model/banner_model.dart';
import '../../../core/model/product_model.dart';
import '../../../core/services/banner_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/product_service.dart';

class HomeProvider extends ChangeNotifier {
  List<CategoryModel> _categories = const [];
  List<ProductModel> _products = const [];
  List<BannerModel> _banners = const [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  bool _hasLoaded = false;
  bool _disposed = false;
  bool _categoryLoadFailed = false;
  bool _categoryRealtimeConnected = false;
  int _categoryReconnectAttempt = 0;

  StreamSubscription<List<BannerModel>>? _bannerSubscription;
  StreamSubscription<List<CategoryModel>>? _categorySubscription;
  StreamSubscription<List<ProductModel>>? _productSubscription;
  Timer? _categoryReconnectTimer;

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<BannerModel> get banners => List.unmodifiable(_banners);
  bool get loading => _loading;
  String? get error => _error;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get isSearching => _searchQuery.isNotEmpty;
  bool get categoryRealtimeConnected => _categoryRealtimeConnected;

  Set<String> get _activeCategoryIds =>
      _categories.map((category) => category.id).toSet();

  List<ProductModel> get _visibleProducts {
    final activeCategoryIds = _activeCategoryIds;
    return _products
        .where(
          (product) =>
              product.categoryId.isEmpty ||
              activeCategoryIds.contains(product.categoryId),
        )
        .toList(growable: false);
  }

  List<ProductModel> get filteredProducts {
    Iterable<ProductModel> list = _visibleProducts;
    if (_selectedCategoryId != null) {
      list = list.where((product) => product.categoryId == _selectedCategoryId);
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where(
        (product) => product.name.toLowerCase().contains(query),
      );
    }
    return list.toList(growable: false);
  }

  List<ProductModel> get popularProducts => _visibleProducts
      .where((product) => product.isPopular)
      .toList(growable: false);

  HomeProvider() {
    refresh();
  }

  Future<void> refresh() async {
    if (_loading && _hasLoaded) return;

    _loading = true;
    _error = null;
    notifyListeners();

    var failedSources = 0;
    var categoryLoadFailed = false;

    final tasks = <Future<void>>[
      CategoryService.getCategories()
          .then((items) {
            _applyCategories(items);
            _categoryLoadFailed = false;
          })
          .catchError((Object error) {
            failedSources++;
            categoryLoadFailed = true;
            debugPrint('Categories initial load failed: $error');
          }),
      ProductService.getProducts()
          .then((items) {
            _products = items;
          })
          .catchError((Object error) {
            failedSources++;
            debugPrint('Products initial load failed: $error');
          }),
      BannerService.getBanners()
          .then((items) {
            _banners = items;
          })
          .catchError((Object error) {
            failedSources++;
            debugPrint('Banners initial load failed: $error');
          }),
    ];

    await Future.wait(tasks);
    if (_disposed) return;

    _hasLoaded = true;
    _loading = false;

    if (categoryLoadFailed) {
      _categoryLoadFailed = true;
      _error =
          'دریافت دسته‌بندی‌ها با مشکل مواجه شد. اتصال اینترنت را بررسی و دوباره تلاش کنید.';
    } else if (failedSources == tasks.length &&
        _categories.isEmpty &&
        _products.isEmpty &&
        _banners.isEmpty) {
      _error =
          'ارتباط با سرور برقرار نشد. اتصال اینترنت و تنظیمات Supabase را بررسی کنید.';
    }

    _listenForRealtimeChanges();
    notifyListeners();
  }

  void _applyCategories(List<CategoryModel> items) {
    _categories = items
        .where((category) => category.isActive)
        .toList(growable: false);

    if (_selectedCategoryId != null &&
        !_categories.any((item) => item.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
  }

  void _listenForRealtimeChanges() {
    _bannerSubscription?.cancel();
    _productSubscription?.cancel();
    _categoryReconnectTimer?.cancel();
    _categoryReconnectAttempt = 0;

    _bannerSubscription = BannerService.watchBanners().listen(
      (items) {
        if (_disposed) return;
        _banners = items;
        _hasLoaded = true;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Banners realtime error: $error'),
    );

    _subscribeToCategoryChanges();

    _productSubscription = ProductService.watchProducts().listen(
      (items) {
        if (_disposed) return;
        _products = items;
        _hasLoaded = true;
        _loading = false;
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Products realtime error: $error'),
    );
  }

  void _subscribeToCategoryChanges() {
    if (_disposed) return;

    _categorySubscription?.cancel();
    _categoryRealtimeConnected = false;

    try {
      _categorySubscription = CategoryService.watchCategories().listen(
        (items) {
          if (_disposed) return;

          _categoryRealtimeConnected = true;
          _categoryReconnectAttempt = 0;
          _categoryReconnectTimer?.cancel();

          _applyCategories(items);
          _hasLoaded = true;
          _loading = false;

          if (_categoryLoadFailed) {
            _categoryLoadFailed = false;
            _error = null;
          }

          notifyListeners();
        },
        onError: (Object error) {
          _categoryRealtimeConnected = false;
          debugPrint('Categories realtime error: $error');
          _scheduleCategoryReconnect();
        },
        onDone: () {
          _categoryRealtimeConnected = false;
          _scheduleCategoryReconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      _categoryRealtimeConnected = false;
      debugPrint('Categories realtime subscription failed: $error');
      _scheduleCategoryReconnect();
    }
  }

  void _scheduleCategoryReconnect() {
    if (_disposed || (_categoryReconnectTimer?.isActive ?? false)) return;

    final exponent = _categoryReconnectAttempt.clamp(0, 5);
    final delaySeconds = exponent >= 5 ? 30 : 1 << exponent;
    _categoryReconnectAttempt = (exponent + 1).clamp(0, 5);

    _categoryReconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () {
        if (_disposed) return;
        _subscribeToCategoryChanges();
      },
    );
  }

  void selectCategory(String? id) {
    if (id != null && !_activeCategoryIds.contains(id)) return;

    _selectedCategoryId = _selectedCategoryId == id ? null : id;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _categoryReconnectTimer?.cancel();
    _bannerSubscription?.cancel();
    _categorySubscription?.cancel();
    _productSubscription?.cancel();
    super.dispose();
  }
}
