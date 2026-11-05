import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/notification_model.dart';
import 'supabase_service.dart';

class NotificationService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Uses the existing CRM customer_notifications table and respects its RLS.
  static Stream<List<NotificationModel>> watchForUser(String userId) => _client
      .from('customer_notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .map((row) => NotificationModel.fromJson(row))
            .toList(growable: false),
      );

  static Future<void> markAsRead({
    required String userId,
    required String notificationId,
  }) async {
    await _client
        .from('customer_notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', notificationId)
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  static Future<void> markAllAsRead(String userId) async {
    await _client
        .from('customer_notifications')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
