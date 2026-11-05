enum OrderStatus {
  pending,    // در انتظار تأیید
  confirmed,  // تأیید شده
  preparing,  // در حال آماده‌سازی
  onTheWay,   // در راه
  delivered,  // تحویل داده شد
  cancelled,  // لغو شده
}

enum OrderType { delivery, pickup, dineIn }

class OrderItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final int unitPrice;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  int get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson(String orderId) => {
        'order_id': orderId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
      };

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
        productId: j['product_id']?.toString() ?? '',
        productName: j['product_name']?.toString() ?? '',
        quantity: _toInt(j['quantity'], fallback: 1),
        unitPrice: _toInt(j['unit_price']),
      );

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? fallback;
  }
}

class OrderModel {
  final String id;
  final String orderCode;
  final List<OrderItemModel> items;
  final int totalPrice;
  final OrderStatus status;
  final OrderType type;
  final DateTime createdAt;
  final DateTime estimatedDelivery;
  final String? address;       // فقط برای دلیوری
  final String? addressId;
  final int? tableNumber;      // فقط برای حضوری
  final String? tableId;
  final String note;

  const OrderModel({
    required this.id,
    required this.orderCode,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.type,
    required this.createdAt,
    required this.estimatedDelivery,
    this.address,
    this.addressId,
    this.tableNumber,
    this.tableId,
    this.note = '',
  });

  OrderModel copyWith({
    String? id,
    String? orderCode,
    List<OrderItemModel>? items,
    int? totalPrice,
    OrderStatus? status,
    OrderType? type,
    DateTime? createdAt,
    DateTime? estimatedDelivery,
    String? address,
    String? addressId,
    int? tableNumber,
    String? tableId,
    String? note,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      items: items ?? this.items,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      address: address ?? this.address,
      addressId: addressId ?? this.addressId,
      tableNumber: tableNumber ?? this.tableNumber,
      tableId: tableId ?? this.tableId,
      note: note ?? this.note,
    );
  }

  // مپ کردن داده‌ها برای ارسال به Supabase
  Map<String, dynamic> toJson() => {
        'order_type': type == OrderType.delivery
            ? 'delivery'
            : (type == OrderType.pickup ? 'pickup' : 'dine_in'),
        'status': 'pending',
        'total_amount': totalPrice,
        'estimated_ready_minutes': estimatedDelivery.difference(createdAt).inMinutes,
        'address_id': addressId,
        'address_line': address,
        'table_number': tableNumber,
        'table_id': tableId,
        'note': note,
      };

  // مپ کردن داده‌های دریافتی از Supabase
  factory OrderModel.fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(j['created_at']?.toString() ?? '')
            ?.toLocal() ??
        DateTime.now();
    final estimateMinutes = _toNullableInt(j['estimated_ready_minutes']);

    return OrderModel(
      id: id,
      orderCode: j['order_code']?.toString() ??
          (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()),
      items: const [],
      totalPrice: _toInt(j['total_amount']),
      status: _parseStatus(j['status'] as String?),
      type: _parseType(j['order_type'] as String?),
      createdAt: createdAt,
      estimatedDelivery: createdAt.add(
        Duration(minutes: estimateMinutes != null && estimateMinutes > 0
            ? estimateMinutes
            : 45),
      ),
      address: j['address_line'] as String?,
      addressId: j['address_id']?.toString(),
      tableNumber: _toNullableInt(j['table_number']),
      tableId: j['table_id']?.toString(),
      note: j['note'] as String? ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.round();
    return num.tryParse(value.toString())?.round();
  }

  static OrderStatus _parseStatus(String? s) {
    switch (s) {
      case 'confirmed': return OrderStatus.confirmed;
      case 'preparing': return OrderStatus.preparing;
      case 'ready':
      case 'out_for_delivery': return OrderStatus.onTheWay;
      case 'completed': return OrderStatus.delivered;
      case 'cancelled': return OrderStatus.cancelled;
      default: return OrderStatus.pending;
    }
  }

  static OrderType _parseType(String? s) {
    switch (s) {
      case 'pickup':
        return OrderType.pickup;
      case 'dine_in':
        return OrderType.dineIn;
      default:
        return OrderType.delivery;
    }
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.pending:   return 'در انتظار تأیید';
      case OrderStatus.confirmed: return 'تأیید شده';
      case OrderStatus.preparing: return 'در حال آماده‌سازی';
      case OrderStatus.onTheWay:  return 'در راه است';
      case OrderStatus.delivered: return 'تحویل داده شد';
      case OrderStatus.cancelled: return 'لغو شده';
    }
  }

  String get statusEmoji {
    switch (status) {
      case OrderStatus.pending:   return '⏳';
      case OrderStatus.confirmed: return '✅';
      case OrderStatus.preparing: return '👨‍🍳';
      case OrderStatus.onTheWay:  return '🛵';
      case OrderStatus.delivered: return '🎉';
      case OrderStatus.cancelled: return '❌';
    }
  }

  int get statusStep => status.index;
}