import 'package:flutter_test/flutter_test.dart';
import 'package:my_project/core/model/banner_model.dart';
import 'package:my_project/core/model/checkout_settings_model.dart';
import 'package:my_project/core/model/notification_model.dart';
import 'package:my_project/core/model/order_model.dart';
import 'package:my_project/core/model/product_model.dart';

void main() {
  group('Supabase model mapping', () {
    test('maps category active state and sort order', () {
      final category = CategoryModel.fromJson({
        'id': 'category-1',
        'name': 'کباب‌ها',
        'image_url': 'https://example.test/kebab.png',
        'sort_order': 4,
        'is_active': true,
      });
      final inactiveCategory = CategoryModel.fromJson({
        'id': 'category-2',
        'name': 'غیرفعال',
        'image_url': '',
        'sort_order': 5,
        'is_active': false,
      });
      final missingStatus = CategoryModel.fromJson({
        'id': 'category-3',
        'name': 'بدون وضعیت',
        'image_url': '',
      });

      expect(category.sortOrder, 4);
      expect(category.isActive, isTrue);
      expect(inactiveCategory.isActive, isFalse);
      expect(missingStatus.isActive, isFalse);
    });

    test('maps all editable CRM banner fields', () {
      final banner = BannerModel.fromJson({
        'id': 'banner-1',
        'title': 'پیشنهاد ویژه',
        'subtitle': 'فقط امروز',
        'promo_title': '۲۰ درصد تخفیف',
        'image_url': 'https://example.test/banner.jpg',
        'logo_url': 'https://example.test/logo.png',
        'discount_code': 'FOOD20',
        'sort_order': 3,
      });

      expect(banner.promoTitle, '۲۰ درصد تخفیف');
      expect(banner.discountCode, 'FOOD20');
      expect(banner.logoUrl, 'https://example.test/logo.png');
      expect(banner.sortOrder, 3);
    });

    test('uses the CRM discounted price while keeping the base price', () {
      final product = ProductModel.fromJson({
        'id': 'product-1',
        'name': 'پیتزا',
        'description': '',
        'about_dish': 'پنیر و قارچ',
        'price': 100000,
        'discounted_price': 80000,
        'discount_percent': 20,
        'image_url': '',
        'rating': 0,
        'review_count': 0,
        'is_popular': false,
        'category_id': 'category-1',
        'labels': ['محبوب'],
      });

      expect(product.price, 80000);
      expect(product.price, isA<int>());
      expect(product.originalPrice, 100000);
      expect(product.originalPrice, isA<int>());
      expect(product.hasDiscount, isTrue);
      expect(product.aboutDish, 'پنیر و قارچ');
      expect(product.labels, contains('محبوب'));
    });

    test('keeps base price when CRM discount is disabled and maps availability', () {
      final product = ProductModel.fromJson({
        'id': 'product-2',
        'name': 'برگر',
        'description': 'توضیح کوتاه',
        'about_dish': 'توضیح کامل',
        'price': 120000,
        'discounted_price': 96000,
        'discount_percent': 20,
        'is_discount_active': false,
        'is_active': true,
        'is_available': false,
        'unavailable_reason': 'اتمام موجودی',
        'sort_order': 4,
        'image_url': '',
        'rating': 0,
        'review_count': 0,
        'is_popular': false,
        'category_id': 'category-1',
      });
      expect(product.price, 120000);
      expect(product.hasDiscount, isFalse);
      expect(product.isActive, isTrue);
      expect(product.isAvailable, isFalse);
      expect(product.unavailableReason, 'اتمام موجودی');
      expect(product.sortOrder, 4);
    });

    test('maps CRM pickup and status values without treating pickup as delivery', () {
      final order = OrderModel.fromJson({
        'id': '12345678-aaaa-bbbb-cccc-123456789012',
        'order_type': 'pickup',
        'status': 'ready',
        'total_amount': '85000.00',
        'created_at': '2026-10-24T12:00:00Z',
        'estimated_ready_minutes': 20,
        'address_line': null,
        'table_number': null,
        'note': '',
      });

      expect(order.type, OrderType.pickup);
      expect(order.status, OrderStatus.onTheWay);
      expect(order.totalPrice, 85000);
      expect(order.totalPrice, isA<int>());
      expect(order.orderCode, '12345678');
    });

    test('parses numeric checkout settings returned as strings', () {
      final settings = CheckoutSettingsModel.fromJson({
        'fixed_delivery_fee': '15000.00',
        'min_delivery_amount': '125000',
      });

      expect(settings.deliveryFee, 15000);
      expect(settings.deliveryFee, isA<int>());
      expect(settings.minimumDeliveryAmount, 125000);
      expect(settings.minimumDeliveryAmount, isA<int>());
    });

    test('maps customer notification read state and type', () {
      final notification = NotificationModel.fromJson({
        'id': 'notification-1',
        'title': 'سفارش آماده شد',
        'body': 'سفارش شما آماده دریافت است.',
        'notification_type': 'order',
        'is_read': true,
        'created_at': '2026-10-24T12:00:00Z',
      });

      expect(notification.type, 'order');
      expect(notification.isRead, isTrue);
    });
  });
}
