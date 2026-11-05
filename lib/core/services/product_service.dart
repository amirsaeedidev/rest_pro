import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/product_model.dart';
import 'supabase_service.dart';

class ProductService {
  static SupabaseClient get _client => SupabaseService.client;
  static const _columns =
      'id, name, description, about_dish, price, discounted_price, discount_percent, labels, image_url, rating, review_count, is_popular, category_id';

  static Future<List<ProductModel>> getProducts() async {
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => ProductModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت محصولات: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت محصولات: $e');
    }
  }

  static Future<List<ProductModel>> getProductsByCategory(
    String categoryId,
  ) async {
    try {
      final rows = await _client
          .from('products')
          .select(_columns)
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => ProductModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
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
          .order('rating', ascending: false)
          .limit(10);
      return (rows as List)
          .map((row) => ProductModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
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
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => ProductModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw Exception('خطا در جستجو: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در جستجو: $e');
    }
  }

  static Stream<List<ProductModel>> watchProducts() => _client
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .map((row) => ProductModel.fromJson(row))
            .toList(growable: false),
      );
}
