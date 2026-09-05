import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stall_models.dart';

/// Storage service responsible for managing Stall POS menus, orders, and tokens.
class StallStorageService {
  static const String _menuKey = 'stall_menu';
  static const String _ordersKey = 'stall_orders';
  static const String _tokenKey = 'stall_next_token';

  // Legacy default dummy names to purge automatically from old storage
  static const Set<String> _legacyDummyNames = {
    'Burger',
    'Fries',
    'Combo Meal',
    'Soda / Water',
  };

  final SharedPreferences? _prefs;

  StallStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Loads menu items, sanitizing any old legacy defaults.
  Future<List<MenuItem>> loadMenu() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_menuKey);
    if (raw == null) return [];

    try {
      final List decoded = jsonDecode(raw) as List;
      final items = decoded
          .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((item) {
            // Automatically purge legacy sample items (ids 1-4 with sample names)
            final isLegacySample = (item.id == '1' || item.id == '2' || item.id == '3' || item.id == '4') &&
                _legacyDummyNames.contains(item.name);
            return !isLegacySample;
          })
          .toList();

      // If we filtered out legacy items, persist the cleaned menu
      if (items.length != decoded.length) {
        await saveMenu(items);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Saves menu items.
  Future<void> saveMenu(List<MenuItem> items) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _menuKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads all orders.
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
  Future<void> saveOrders(List<StallOrder> orders) async {
    final prefs = await _getPrefs();
    await prefs.setString(
      _ordersKey,
      jsonEncode(orders.map((e) => e.toJson()).toList()),
    );
  }

  /// Loads the next order token counter.
  Future<int> loadNextToken() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_tokenKey) ?? 1;
  }

  /// Saves the next order token counter.
  Future<void> saveNextToken(int token) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_tokenKey, token);
  }

  /// Deletes only completed orders from storage, keeping active/pending orders intact.
  Future<List<StallOrder>> clearCompletedOrders() async {
    final current = await loadOrders();
    final remaining = current.where((o) => !o.isCompleted).toList();
    await saveOrders(remaining);
    return remaining;
  }

  /// Clears all order history entirely and resets token counter.
  Future<void> clearAllOrders({bool resetToken = false}) async {
    final prefs = await _getPrefs();
    await prefs.remove(_ordersKey);
    if (resetToken) {
      await prefs.setInt(_tokenKey, 1);
    }
  }
}
