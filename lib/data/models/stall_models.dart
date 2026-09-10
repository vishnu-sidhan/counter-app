import '../../theme/category_colors.dart';

// Data models for the Stall POS screen and orders.

class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final int? colorHex;
  final bool isAddon;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.category = 'General',
    this.colorHex,
    this.isAddon = false,
  });

  /// Check if this item qualifies as an add-on either via explicit flag
  /// or category name containing 'addon' or 'extra'.
  bool get effectiveIsAddon {
    if (isAddon) return true;
    final cat = category.toLowerCase();
    return cat.contains('addon') || cat.contains('add-on') || cat == 'extras' || cat == 'extra';
  }

  /// Centralized display name showing item name and category in brackets:
  /// e.g. "Masala Chai (Beverages)" or "[Extra Cheese] Veg Burger (Fast Food)".
  String get displayName {
    final cat = category.trim();
    if (cat.isNotEmpty && !name.endsWith('($cat)')) {
      return '$name ($cat)';
    }
    return name;
  }

  /// Whether the item name contains '/' indicating multiple or-variants.
  bool get hasSlashNameVariants => name.contains('/');

  /// List of separated variant names when split by '/'.
  List<String> get slashNameVariants {
    if (!hasSlashNameVariants) return [name];
    return name
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Whether the category contains '/' indicating multiple or-categories.
  bool get hasSlashCategoryVariants => category.contains('/');

  /// List of separated category names when split by '/'.
  List<String> get slashCategoryVariants {
    if (!hasSlashCategoryVariants) return [category];
    return category
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Whether the item has any '/' variants in name or category.
  bool get hasAnySlashVariants => hasSlashNameVariants || hasSlashCategoryVariants;

  /// Backwards-compatible aliases
  bool get hasSlashVariants => hasSlashNameVariants;
  List<String> get slashVariants => slashNameVariants;

  MenuItem copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    int? colorHex,
    bool clearColor = false,
    bool? isAddon,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      colorHex: clearColor ? null : (colorHex ?? this.colorHex),
      isAddon: isAddon ?? this.isAddon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'category': category,
        if (colorHex != null) 'colorHex': colorHex,
        if (isAddon) 'isAddon': isAddon,
      };

  factory MenuItem.fromJson(Map<String, dynamic> map) {
    final category = (map['category']?.toString().trim().isNotEmpty == true)
        ? map['category']!.toString().trim()
        : 'General';
    final parsedColor = map['colorHex'] != null
        ? (map['colorHex'] as num?)?.toInt()
        : CategoryColorHelper.parseColor(map['color']);
    final isAddonExplicit = map['isAddon'] == true;
    return MenuItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: category,
      colorHex: parsedColor ?? CategoryColorHelper.getColorForCategory(category),
      isAddon: isAddonExplicit,
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
  final double paidAmount;
  final Map<String, int> paidItems;
  final Map<String, int> completedItems;
  final Map<String, Map<String, dynamic>> itemSnapshots;

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
    this.paidAmount = 0.0,
    this.paidItems = const {},
    this.completedItems = const {},
    this.itemSnapshots = const {},
  });

  String get displayCustomerName {
    if (customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    return 'Walk-in Customer';
  }

  /// Balance amount remaining to be paid
  double get remainingDue => (total - paidAmount) > 0 ? (total - paidAmount) : 0.0;

  /// Whether this order has had a previous payment but still has an unpaid balance
  bool get hasPartialPayment => paidAmount > 0 && remainingDue > 0;

  /// Whether this order is completely paid
  bool get isFullyPaid => isPaid && remainingDue == 0;

  /// Returns the completed quantity for a specific item.
  int getCompletedQuantity(String itemId) {
    if (isCompleted) {
      return items[itemId] ?? 0;
    }
    return completedItems[itemId] ?? 0;
  }

  /// Returns remaining uncompleted quantity for a specific item.
  int getPendingQuantity(String itemId) {
    final total = items[itemId] ?? 0;
    final completed = getCompletedQuantity(itemId);
    return (total - completed) > 0 ? (total - completed) : 0;
  }

  /// Returns true if an item is fully completed.
  bool isItemCompleted(String itemId) {
    return getPendingQuantity(itemId) <= 0;
  }

  /// Returns true if all items in this order are completed.
  bool get areAllItemsCompleted {
    if (isCompleted) return true;
    if (items.isEmpty) return false;
    for (final entry in items.entries) {
      if ((completedItems[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  /// Total count of all items in this order.
  int get totalItemsCount => items.values.fold<int>(0, (sum, q) => sum + q);

  /// Total count of completed items in this order.
  int get completedItemsCount {
    if (isCompleted) return totalItemsCount;
    int count = 0;
    for (final entry in items.entries) {
      final done = completedItems[entry.key] ?? 0;
      count += (done > entry.value) ? entry.value : done;
    }
    return count;
  }

  /// Completion progress ratio from 0.0 to 1.0.
  double get completionProgress {
    if (isCompleted) return 1.0;
    final total = totalItemsCount;
    if (total <= 0) return 0.0;
    return (completedItemsCount / total).clamp(0.0, 1.0);
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
    double? paidAmount,
    Map<String, int>? paidItems,
    Map<String, int>? completedItems,
    Map<String, Map<String, dynamic>>? itemSnapshots,
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
      paidAmount: paidAmount ?? this.paidAmount,
      paidItems: paidItems ?? this.paidItems,
      completedItems: completedItems ?? this.completedItems,
      itemSnapshots: itemSnapshots ?? this.itemSnapshots,
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
        'paidAmount': paidAmount,
        'paidItems': paidItems,
        if (completedItems.isNotEmpty) 'completedItems': completedItems,
        if (itemSnapshots.isNotEmpty) 'itemSnapshots': itemSnapshots,
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

    final isPaidVal = map['isPaid'] == true;
    final totalVal = (map['total'] as num?)?.toDouble() ?? 0.0;
    final paidAmountVal = (map['paidAmount'] as num?)?.toDouble() ?? (isPaidVal ? totalVal : 0.0);

    Map<String, int> parsedPaidItems = {};
    if (map['paidItems'] is Map) {
      (map['paidItems'] as Map).forEach((k, v) {
        if (v is num) {
          parsedPaidItems[k.toString()] = v.toInt();
        }
      });
    } else if (isPaidVal) {
      parsedPaidItems = Map.from(parsedItems);
    }

    Map<String, int> parsedCompletedItems = {};
    if (map['completedItems'] is Map) {
      (map['completedItems'] as Map).forEach((k, v) {
        if (v is num) {
          parsedCompletedItems[k.toString()] = v.toInt();
        }
      });
    } else if (map['isCompleted'] == true) {
      parsedCompletedItems = Map.from(parsedItems);
    }

    Map<String, Map<String, dynamic>> parsedSnapshots = {};
    if (map['itemSnapshots'] is Map) {
      (map['itemSnapshots'] as Map).forEach((k, v) {
        if (v is Map) {
          parsedSnapshots[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    return StallOrder(
      token: (map['token'] as num?)?.toInt() ?? 0,
      itemsSummary: map['itemsSummary']?.toString() ?? '',
      total: totalVal,
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isCompleted: map['isCompleted'] == true,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      customerName: map['customerName']?.toString(),
      isPaid: isPaidVal,
      paymentMethod: map['paymentMethod']?.toString(),
      items: parsedItems,
      paidAmount: paidAmountVal,
      paidItems: parsedPaidItems,
      completedItems: parsedCompletedItems,
      itemSnapshots: parsedSnapshots,
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

  /// Centralized display name showing item name with category in brackets:
  /// e.g. "Masala Chai (Beverages)".
  String get displayName {
    final cat = category.trim();
    if (cat.isNotEmpty && !itemName.endsWith('($cat)')) {
      return '$itemName ($cat)';
    }
    return itemName;
  }
}

/// Represents an individual add-on entry in an item's breakdown.
class CartItemAddonDetail {
  final String name;
  final int count;
  final double singlePrice;
  final double totalPrice;

  const CartItemAddonDetail({
    required this.name,
    required this.count,
    required this.singlePrice,
    required this.totalPrice,
  });
}

/// Represents the monetary breakdown between a base item and its linked add-ons.
class CartItemBreakdown {
  final MenuItem baseItem;
  final double basePrice;
  final double addonsPrice;
  final double totalUnitPrice;
  final List<CartItemAddonDetail> addonDetails;

  const CartItemBreakdown({
    required this.baseItem,
    required this.basePrice,
    required this.addonsPrice,
    required this.totalUnitPrice,
    required this.addonDetails,
  });

  bool get hasAddons => addonsPrice > 0 || addonDetails.isNotEmpty;
}

