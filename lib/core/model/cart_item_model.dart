import 'product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  String note;
  final String snapshotName;
  final int snapshotPrice;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.note = '',
    String? snapshotName,
    int? snapshotPrice,
  })  : snapshotName = snapshotName ?? product.name,
        snapshotPrice = snapshotPrice ?? product.price;

  int get totalPrice => product.price * quantity;

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    String? note,
    String? snapshotName,
    int? snapshotPrice,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      snapshotName: snapshotName ?? this.snapshotName,
      snapshotPrice: snapshotPrice ?? this.snapshotPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'note': note,
      'snapshot_name': snapshotName,
      'snapshot_price': snapshotPrice,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      note: json['note'] as String? ?? '',
      snapshotName: json['snapshot_name'] as String?,
      snapshotPrice: (json['snapshot_price'] as num?)?.round(),
    );
  }
}