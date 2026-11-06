import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/discount_model.dart';
import '../model/cart_item_model.dart';

class DiscountResult {
  final bool success;
  final String? errorMessage;
  final DiscountModel? discount;
  final int discountAmount;

  const DiscountResult({
    required this.success,
    this.errorMessage,
    this.discount,
    this.discountAmount = 0,
  });

  factory DiscountResult.error(String message) =>
      DiscountResult(success: false, errorMessage: message);

  factory DiscountResult.ok(DiscountModel discount, int amount) =>
      DiscountResult(success: true, discount: discount, discountAmount: amount);
}

class DiscountService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const _table = 'discounts';

  // ── خواندن کدهای تخفیف فعال (عمومی) ──
  static Future<List<DiscountModel>> fetchAvailableDiscounts() async {
    try {
      final rows = await _client.rpc('list_customer_discounts');

      return (rows as List)
          .map((r) => DiscountModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('خطا در دریافت تخفیف‌ها: ${e.message}');
    }
  }

  /// Streams active CRM discounts so edits in the admin app appear without restart.
  static Stream<List<DiscountModel>> watchAvailableDiscounts() => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .map((row) => DiscountModel.fromJson(row))
            .toList(growable: false),
      );

  // ── اعمال کد با validation کامل ──
  static Future<DiscountResult> applyCode({
    required String code,
    required List<CartItemModel> items,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return DiscountResult.error('کد تخفیف را وارد کنید');

    try {
      final response = await _client.rpc(
        'quote_discount_code',
        params: {
          'p_code': normalized,
          'p_items': items.map((item) => {
            'product_id': item.product.id,
            'quantity': item.quantity,
          }).toList(growable: false),
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] != true) {
        return DiscountResult.error(
          (result['message'] ?? 'کد تخفیف قابل استفاده نیست.').toString(),
        );
      }
      final discount = DiscountModel.fromJson({
        'id': result['discount_id'],
        'code': result['code'],
        'title': result['title'],
        'description': result['description'],
        'discount_type': result['discount_type'],
        'discount_value': result['discount_value'],
        'min_order_amount': result['min_order_amount'],
        'max_discount_amount': result['max_discount_amount'],
        'starts_at': result['starts_at'],
        'expires_at': result['expires_at'],
        'is_active': result['is_active'],
      });
      final amount = (result['discount_amount'] as num?)?.round() ?? 0;
      return DiscountResult.ok(discount, amount);
    } on PostgrestException catch (e) {
      return DiscountResult.error('خطای سرور: ${e.message}');
    } catch (_) {
      return DiscountResult.error('خطای غیرمنتظره. دوباره تلاش کنید');
    }
  }

  // Discount usage is committed atomically by place_order_idempotent.
  // This compatibility method intentionally performs no database write.
  @Deprecated('Usage is recorded by the transactional order RPC.')
  static Future<void> markAsUsed({required String discountId}) async {}

  static String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    final offset = s.length % 3;
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}