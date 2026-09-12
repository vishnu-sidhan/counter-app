import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stall_models.dart';
import '../storage/stall_storage.dart';

/// Local storage service responsible for managing Stall POS menus, orders, and tokens via SharedPreferences.
class StallStorageService implements StallStorage {
  static const String _menuKey = 'stall_menu';
  static const String _ordersKey = 'stall_orders';
  static const String _tokenKey = 'stall_next_token';
  static const String _categoriesKey = 'stall_categories';

  final SharedPreferences? _prefs;

  StallStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Loads menu items.
  @override
  Future<List<MenuItem>> loadMenu() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_menuKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves menu items.
  @override
  Future<void> saveMenu(List<MenuItem> items) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _menuKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads all orders.
  @override
  Future<List<StallOrder>> loadOrders() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_ordersKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => StallOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves orders.
  @override
  Future<void> saveOrders(List<StallOrder> orders) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _ordersKey,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads the next order token counter.
  @override
  Future<int> loadNextToken() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_tokenKey) ?? 1;
  }

  /// Saves the next order token counter.
  @override
  Future<void> saveNextToken(int token) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_tokenKey, token);
  }

  /// Deletes only completed orders from storage, keeping active/pending orders intact.
  @override
  Future<List<StallOrder>> clearCompletedOrders() async {
    final current = await loadOrders();
    final remaining = current.where((o) => !o.isCompleted).toList();
    await saveOrders(remaining);
    return remaining;
  }

  static const String _archiveKey = 'stall_orders_archive';

  /// Archives completed orders into a separate archive store,
  /// keeping the active orders list lightweight.
  /// If [explicitOrders] is provided, archives those specific orders;
  /// otherwise archives orders completed longer ago than [threshold].
  @override
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  }) async {
    final prefs = await _getPrefs();
    final currentOrders = await loadOrders();
    final now = DateTime.now();

    final toKeep = <StallOrder>[];
    final toArchive = <StallOrder>[];

    if (explicitOrders != null) {
      final explicitTokens = explicitOrders.map((o) => o.token).toSet();
      for (final order in currentOrders) {
        if (explicitTokens.contains(order.token)) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    } else {
      for (final order in currentOrders) {
        if (order.isCompleted &&
            order.completedAt != null &&
            now.difference(order.completedAt!) > threshold) {
          toArchive.add(order);
        } else {
          toKeep.add(order);
        }
      }
    }

    if (toArchive.isEmpty) return 0;

    final existingArchived = await loadArchivedOrders();
    final combinedArchive = [...existingArchived, ...toArchive];

    await prefs.setString(
      _archiveKey,
      jsonEncode(combinedArchive.map((e) => e.toJson()).toList()),
    );
    await saveOrders(toKeep);

    return toArchive.length;
  }

  /// Loads archived orders from storage.
  @override
  Future<List<StallOrder>> loadArchivedOrders() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_archiveKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => StallOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears all order history entirely and resets token counter.
  @override
  Future<void> clearAllOrders({bool resetToken = false}) async {
    final prefs = await _getPrefs();
    await prefs.remove(_ordersKey);
    await prefs.remove(_archiveKey);
    if (resetToken) {
      await prefs.setInt(_tokenKey, 1);
    }
  }

  /// Loads category configurations and additional costs.
  @override
  Future<List<ItemCategory>> loadCategories() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => ItemCategory.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves category configurations.
  @override
  Future<void> saveCategories(List<ItemCategory> categories) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );
  }
}
