import '../../theme/category_colors.dart';

// Data models for the Stall POS screen and orders.

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final int? colorHex;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.category = 'General',
    this.colorHex,
  });

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    int? colorHex,
    bool clearColor = false,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category,
        if (colorHex != null) 'colorHex': colorHex,
      };

  factory MenuItem.fromJson(Map<String, dynamic> map) {
    final category = (map['category']?.toString().trim().isNotEmpty == true)
        ? map['category']!.toString().trim()
        : 'General';
    final parsedColor = map['colorHex'] != null
        ? (map['colorHex'] as num?)?.toInt()
        : CategoryColorHelper.parseColor(map['color']);
    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: category,
      colorHex: parsedColor ?? CategoryColorHelper.getColorForCategory(category),
    );
  }
}

class StallOrder {
  final int token;
  final String itemsSummary;
  final double total;
  final DateTime timestamp;
  bool isCompleted;
  DateTime? completedAt;

  StallOrder({
    required this.token,
    required this.itemsSummary,
    required this.total,
    required this.timestamp,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'itemsSummary': itemsSummary,
        'total': total,
        'timestamp': timestamp.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  factory StallOrder.fromJson(Map<String, dynamic> map) => StallOrder(
        token: (map['token'] as num?)?.toInt() ?? 0,
        itemsSummary: map['itemsSummary']?.toString() ?? '',
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
        isCompleted: map['isCompleted'] == true,
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'].toString())
            : null,
      );
}
