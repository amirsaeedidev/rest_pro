import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/checkout_settings_model.dart';
import 'supabase_service.dart';

class CheckoutSettingsService {
  static SupabaseClient get _client => SupabaseService.client;

  static Stream<CheckoutSettingsModel> watchSettings() => _client
      .from('restaurant_settings')
      .stream(primaryKey: ['id'])
      .eq('id', 'restaurant')
      .map((rows) {
        if (rows.isEmpty) return const CheckoutSettingsModel();
        return CheckoutSettingsModel.fromJson(rows.first);
      });
}
