import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/product_model.dart';
import 'supabase_service.dart';

class ProductService {
  static SupabaseClient get _client => SupabaseService.client;
  static const _columns =
      'id, name, description, about_dish, price, discounted_price, discount_percent, is_discount_active, labels, image_url, rating, review_count, is_popular, category_id, created_at, is_active, is_available, unavailable_reason, sort_order';

  static List<ProductModel> _mapRows(List<dynamic> rows) => rows
      .map((row) => ProductModel.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);

  // Initial catalog reads return active products only. The unfiltered Realtime
  // stream below observes active -> inactive transitions under the public metadata policy.
  static Future<List<ProductModel>> getProducts() async {
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return _mapRows(rows as List);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت محصولات: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت محصولات: $e');
    }
  }

  static Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return _mapRows(rows as List);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت محصولات دسته‌بندی: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت محصولات: $e');
    }
  }

  static Future<List<ProductModel>> getPopularProducts() async {
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .eq('is_popular', true)
          .eq('is_active', true)
          .eq('is_available', true)
          .order('sort_order', ascending: true)
          .limit(10);
      return _mapRows(rows as List);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت محصولات پرطرفدار: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت محصولات: $e');
    }
  }

  static Future<List<ProductModel>> searchProducts(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return getProducts();
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .ilike('name', '%$normalized%')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return _mapRows(rows as List);
    } on PostgrestException catch (e) {
      throw Exception('خطا در جستجو: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در جستجو: $e');
    }
  }

  /// Reads the current server state for the exact products already in the cart.
  /// Includes inactive rows so checkout can explain removals instead of silently dropping them.
  static Future<List<ProductModel>> getProductsByIds(List<String> productIds) async {
    if (productIds.isEmpty) return const [];
    final rows = await _client
        .from('products')
        .select(_columns)
        .inFilter('id', productIds);
    return _mapRows(rows as List);
  }

  // No server-side is_active filter: a deactivation event must reach the client.
  static Stream<List<ProductModel>> watchProducts() => _client
      .from('products')
      .stream(primaryKey: ['id'])
      .order('sort_order', ascending: true)
      .order('created_at', ascending: false)
      .map(_mapRows);
}
