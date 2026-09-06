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
  final String? customerName;
  final bool isPaid;
  final String? paymentMethod;
  final Map<String, int> items;

  StallOrder({
    required this.token,
    required this.itemsSummary,
    required this.total,
    required this.timestamp,
    this.isCompleted = false,
    this.completedAt,
    this.customerName,
    this.isPaid = false,
    this.paymentMethod,
    this.items = const {},
  });

  String get displayCustomerName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    return 'Walk-in Customer';
  }

  StallOrder copyWith({
    int? token,
    String? itemsSummary,
    double? total,
    DateTime? timestamp,
    bool? isCompleted,
    DateTime? completedAt,
    String? customerName,
    bool clearCustomerName = false,
    bool? isPaid,
    String? paymentMethod,
    Map<String, int>? items,
  }) {
    return StallOrder(
      token: token ?? this.token,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      total: total ?? this.total,
      timestamp: timestamp ?? this.timestamp,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      customerName: clearCustomerName ? null : (customerName ?? this.customerName),
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'itemsSummary': itemsSummary,
        'total': total,
        'timestamp': timestamp.toIso8601String(),
        'isCompleted': isCompleted,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (customerName != null) 'customerName': customerName,
        'isPaid': isPaid,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'items': items,
      };

  factory StallOrder.fromJson(Map<String, dynamic> map) {
    Map<String, int> parsedItems = {};
    if (map['items'] is Map) {
      (map['items'] as Map).forEach((k, v) {
        if (v is num) {
          parsedItems[k.toString()] = v.toInt();
        }
      });
    }

    return StallOrder(
      token: (map['token'] as num?)?.toInt() ?? 0,
      itemsSummary: map['itemsSummary']?.toString() ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isCompleted: map['isCompleted'] == true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      customerName: map['customerName']?.toString(),
      isPaid: map['isPaid'] == true,
      paymentMethod: map['paymentMethod']?.toString(),
      items: parsedItems,
    );
  }
}

/// Alias for StallOrder matching generic requirements
typedef Order = StallOrder;

/// Ticket contribution to an aggregated item in the consolidated queue
class OrderTicketQuantity {
  final int token;
  final int quantity;

  const OrderTicketQuantity({
    required this.token,
    required this.quantity,
  });
}

/// Aggregated item across active orders for kitchen consolidated prep
class AggregatedOrderItem {
  final String itemId;
  final String itemName;
  final String category;
  final int totalQuantity;
  final List<OrderTicketQuantity> tickets;
  final int? colorHex;

  const AggregatedOrderItem({
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.totalQuantity,
    required this.tickets,
    this.colorHex,
  });
}

