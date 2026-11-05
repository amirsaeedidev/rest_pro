class CheckoutSettingsModel {
  final int deliveryFee;
  final int minimumDeliveryAmount;

  const CheckoutSettingsModel({
    this.deliveryFee = 0,
    this.minimumDeliveryAmount = 0,
  });

  factory CheckoutSettingsModel.fromJson(Map<String, dynamic> json) =>
      CheckoutSettingsModel(
        deliveryFee: _toInt(json['fixed_delivery_fee']),
        minimumDeliveryAmount: _toInt(json['min_delivery_amount']),
      );

  static int _toInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }
}
