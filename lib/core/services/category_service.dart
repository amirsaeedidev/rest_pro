import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/product_model.dart';
import 'supabase_service.dart';

class CategoryService {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<List<CategoryModel>> getCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select('id, name, image_url, sort_order, loyalty_points_per_item')
          .eq('is_active', true)
          .order('sort_order');

      return (rows as List)
          .map((row) => CategoryModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت دسته‌بندی‌ها: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت دسته‌بندی‌ها: $e');
    }
  }

  static Stream<List<CategoryModel>> watchCategories() => _client
      .from('categories')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('sort_order')
      .map(
        (rows) => rows
            .map((row) => CategoryModel.fromJson(row))
            .toList(growable: false),
      );
}
