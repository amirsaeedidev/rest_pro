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

  StreamSubscription<List<BannerModel>>? _bannerSubscription;
  StreamSubscription<List<CategoryModel>>? _categorySubscription;
  StreamSubscription<List<ProductModel>>? _productSubscription;

  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<BannerModel> get banners => List.unmodifiable(_banners);
  bool get loading => _loading;
  String? get error => _error;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get isSearching => _searchQuery.isNotEmpty;

  List<ProductModel> get filteredProducts {
    Iterable<ProductModel> list = _products;
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

  List<ProductModel> get popularProducts =>
      _products.where((product) => product.isPopular).toList(growable: false);

  HomeProvider() {
    refresh();
  }

  Future<void> refresh() async {
    if (_loading && _hasLoaded) return;
    _loading = true;
    _error = null;
    notifyListeners();

    var failedSources = 0;
    final tasks = <Future<void>>[
      CategoryService.getCategories()
          .then((items) {
            _categories = items;
          })
          .catchError((Object error) {
            failedSources++;
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
    if (failedSources == tasks.length &&
        _categories.isEmpty &&
        _products.isEmpty &&
        _banners.isEmpty) {
      _error =
          'ارتباط با سرور برقرار نشد. اتصال اینترنت و تنظیمات Supabase را بررسی کنید.';
    }

    _listenForRealtimeChanges();
    notifyListeners();
  }

  void _listenForRealtimeChanges() {
    _bannerSubscription?.cancel();
    _categorySubscription?.cancel();
    _productSubscription?.cancel();

    _bannerSubscription = BannerService.watchBanners().listen((items) {
      _banners = items;
      _hasLoaded = true;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) => debugPrint('Banners realtime error: $error'));

    _categorySubscription = CategoryService.watchCategories().listen(
      (items) {
        _categories = items;
        _hasLoaded = true;
        _loading = false;
        _error = null;
        if (_selectedCategoryId != null &&
            !items.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
        notifyListeners();
      },
      onError: (Object error) =>
          debugPrint('Categories realtime error: $error'),
    );

    _productSubscription = ProductService.watchProducts().listen(
      (items) {
        _products = items;
        _hasLoaded = true;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) => debugPrint('Products realtime error: $error'),
    );
  }

  void selectCategory(String? id) {
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
    _bannerSubscription?.cancel();
    _categorySubscription?.cancel();
    _productSubscription?.cancel();
    super.dispose();
  }
}
