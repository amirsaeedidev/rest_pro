import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/restaurant_table_model.dart';
import 'supabase_service.dart';

class RestaurantTableService {
  static SupabaseClient get _client => SupabaseService.client;

  static Stream<List<RestaurantTableModel>> watchAvailableTables() => _client
      .from('restaurant_tables')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .eq('is_occupied', false)
      .order('table_number')
      .map(
        (rows) => rows
            .map((row) => RestaurantTableModel.fromJson(row))
            .where((table) => table.id.isNotEmpty && table.tableNumber > 0)
            .toList(growable: false),
      );
}
