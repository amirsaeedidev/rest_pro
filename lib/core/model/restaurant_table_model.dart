class RestaurantTableModel {
  final String id;
  final int tableNumber;
  final int capacity;
  final bool isOccupied;

  const RestaurantTableModel({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    required this.isOccupied,
  });

  factory RestaurantTableModel.fromJson(Map<String, dynamic> json) =>
      RestaurantTableModel(
        id: json['id']?.toString() ?? '',
        tableNumber: (json['table_number'] as num?)?.toInt() ?? 0,
        capacity: (json['capacity'] as num?)?.toInt() ?? 2,
        isOccupied: json['is_occupied'] as bool? ?? false,
      );
}
