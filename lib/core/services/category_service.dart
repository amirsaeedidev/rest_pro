import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/product_model.dart';
import 'supabase_service.dart';

class CategoryService {
  static SupabaseClient get _client => SupabaseService.client;

  static const String _columns =
      'id, name, image_url, sort_order, is_active, loyalty_points_per_item';

  /// Loads only categories that are currently available to customers.
  static Future<List<CategoryModel>> getCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select(_columns)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (rows as List)
          .map((row) => CategoryModel.fromJson(row as Map<String, dynamic>))
          .where((category) => category.isActive)
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت دسته‌بندی‌ها: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت دسته‌بندی‌ها: $e');
    }
  }

  /// Emits an initial snapshot and then keeps the customer catalog in sync.
  ///
  /// Filtering on the database prevents inactive categories from being
  /// included in customer-facing category results. The provider also filters
  /// products against the active category IDs to avoid showing orphaned items.
  static Stream<List<CategoryModel>> watchCategories() => _client
      .from('categories')
      .stream(primaryKey: ['id'])
      // Subscribe to inactive rows too, so deactivation events are observable.
      // The mapper below keeps them out of the customer-facing catalog.
      .order('sort_order', ascending: true)
      .map(
        (rows) => rows
            .map((row) => CategoryModel.fromJson(row))
            .where((category) => category.isActive)
            .toList(growable: false),
      );
}
