class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String promoTitle;
  final String imageUrl;
  final String? logoUrl;
  final String? discountCode;
  final int sortOrder;

  const BannerModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.sortOrder,
    this.subtitle = '',
    this.promoTitle = '',
    this.logoUrl,
    this.discountCode,
  });

  factory BannerModel.fromJson(Map<String, dynamic> row) => BannerModel(
        id: row['id']?.toString() ?? '',
        title: row['title'] as String? ?? '',
        subtitle: row['subtitle']?.toString() ?? '',
        promoTitle: row['promo_title']?.toString() ?? '',
        imageUrl: row['image_url']?.toString() ?? '',
        logoUrl: row['logo_url']?.toString(),
        discountCode: row['discount_code']?.toString(),
        sortOrder: row['sort_order'] is num
            ? (row['sort_order'] as num).toInt()
            : int.tryParse(row['sort_order']?.toString() ?? '') ?? 0,
      );
}
