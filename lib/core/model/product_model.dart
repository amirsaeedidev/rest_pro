class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final int loyaltyPointsPerItem;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.loyaltyPointsPerItem = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_url': imageUrl,
        'loyalty_points_per_item': loyaltyPointsPerItem,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        loyaltyPointsPerItem: _parseInt(json['loyalty_points_per_item']),
      );

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ProductModel {
  /// The payable price. When a CRM discount is active, this is the discounted price.
  final String id;
  final String name;
  final String description;
  final int price;
  final String imageUrl;
  final double rating;
  final int reviewCount;
  final bool isPopular;
  final String categoryId;
  final int originalPrice;
  final int discountPercent;
  final List<String> labels;
  final String aboutDish;
  final bool isActive;
  final bool isAvailable;
  final bool isDiscountActive;
  final String unavailableReason;
  final int sortOrder;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.reviewCount,
    required this.isPopular,
    required this.categoryId,
    this.originalPrice = 0,
    this.discountPercent = 0,
    this.labels = const [],
    this.aboutDish = '',
    this.isActive = true,
    this.isAvailable = true,
    this.isDiscountActive = true,
    this.unavailableReason = '',
    this.sortOrder = 0,
  });

  bool get hasDiscount => isDiscountActive && discountPercent > 0 && originalPrice > price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        // Persist the original/base price; discount is represented separately.
        'price': originalPrice > 0 ? originalPrice : price,
        'image_url': imageUrl,
        'rating': rating,
        'review_count': reviewCount,
        'is_popular': isPopular,
        'category_id': categoryId,
        'about_dish': aboutDish,
        'labels': labels,
        'discount_percent': discountPercent,
        'is_active': isActive,
        'is_available': isAvailable,
        'is_discount_active': isDiscountActive,
        'unavailable_reason': unavailableReason,
        'sort_order': sortOrder,
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final basePrice = _parseInt(json['price']);
    final discountPercent = _parseInt(json['discount_percent']).clamp(0, 100).toInt();
    final storedDiscountedPrice = _parseNullableInt(json['discounted_price']);
    final calculatedDiscountedPrice =
        (basePrice * (100 - discountPercent) / 100).round();
    final payablePrice = discountPercent > 0
        ? (storedDiscountedPrice ?? calculatedDiscountedPrice)
        : basePrice;
    final description = json['description'] as String? ?? '';
    final aboutDish = json['about_dish'] as String? ?? '';
    final rawLabels = json['labels'];

    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: description,
      price: payablePrice,
      imageUrl: json['image_url'] as String? ?? '',
      rating: _parseDouble(json['rating']),
      reviewCount: _parseInt(json['review_count']),
      isPopular: json['is_popular'] as bool? ?? false,
      categoryId: json['category_id']?.toString() ?? '',
      originalPrice: basePrice,
      discountPercent: discountPercent,
      labels: rawLabels is List
          ? rawLabels.whereType<String>().toList(growable: false)
          : const [],
      aboutDish: aboutDish.trim().isEmpty ? description : aboutDish,
      isActive: json['is_active'] as bool? ?? true,
      isAvailable: json['is_available'] as bool? ?? true,
      isDiscountActive: json['is_discount_active'] as bool? ?? (discountPercent > 0),
      unavailableReason: json['unavailable_reason'] as String? ?? '',
      sortOrder: _parseInt(json['sort_order']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.round();
    return num.tryParse(value.toString())?.round();
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
