import 'package:flutter_test/flutter_test.dart';
import 'package:my_project/core/model/cart_item_model.dart';
import 'package:my_project/core/model/product_model.dart';

ProductModel _product({required String name, required int price}) => ProductModel(
      id: 'product-1',
      name: name,
      description: '',
      price: price,
      imageUrl: '',
      rating: 0,
      reviewCount: 0,
      isPopular: false,
      categoryId: 'category-1',
    );

void main() {
  group('CartItemModel snapshots', () {
    test('preserves original name and price when the live product changes', () {
      final item = CartItemModel(
        product: _product(name: 'برگر قدیمی', price: 120000),
        quantity: 2,
      );

      final updated = item.copyWith(
        product: _product(name: 'برگر جدید', price: 145000),
      );

      expect(updated.product.name, 'برگر جدید');
      expect(updated.product.price, 145000);
      expect(updated.snapshotName, 'برگر قدیمی');
      expect(updated.snapshotPrice, 120000);
      expect(updated.totalPrice, 290000);
    });

    test('round-trips snapshot fields through local cart persistence', () {
      final item = CartItemModel(
        product: _product(name: 'پیتزا', price: 180000),
        quantity: 3,
        snapshotName: 'پیتزای قبلی',
        snapshotPrice: 160000,
      );

      final restored = CartItemModel.fromJson(item.toJson());

      expect(restored.snapshotName, 'پیتزای قبلی');
      expect(restored.snapshotPrice, 160000);
      expect(restored.quantity, 3);
    });
  });
}
