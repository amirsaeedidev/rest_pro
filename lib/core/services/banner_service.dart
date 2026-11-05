import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/banner_model.dart';
import 'supabase_service.dart';

class BannerService {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<List<BannerModel>> getBanners() async {
    try {
      final rows = await _client
          .from('banners')
          .select(
            'id, title, subtitle, promo_title, image_url, logo_url, discount_code, sort_order',
          )
          .eq('is_active', true)
          .order('sort_order');

      return (rows as List)
          .map((row) => BannerModel.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت بنرها: ${e.message}');
    } catch (e) {
      throw Exception('خطای غیرمنتظره در دریافت بنرها: $e');
    }
  }

  /// Emits the current active banners and then every change from the CRM.
  static Stream<List<BannerModel>> watchBanners() => _client
      .from('banners')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('sort_order')
      .map(
        (rows) => rows
            .map((row) => BannerModel.fromJson(row))
            .toList(growable: false),
      );
}
