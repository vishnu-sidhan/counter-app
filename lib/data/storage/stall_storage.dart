import '../models/stall_models.dart';

/// Abstract storage contract for Stall POS menus, orders, and tokens.
/// Allows swapping between local persistence (SharedPreferences/SQLite/Hive)
/// and remote cloud backends (REST API, Firebase, Supabase).
abstract class StallStorage {
  /// Loads all menu items.
  Future<List<MenuItem>> loadMenu();

  /// Persists all menu items.
  Future<void> saveMenu(List<MenuItem> items);

  /// Loads all active/pending orders.
  Future<List<StallOrder>> loadOrders();

  /// Persists orders.
  Future<void> saveOrders(List<StallOrder> orders);

  /// Loads the next order token counter.
  Future<int> loadNextToken();

  /// Persists the next order token counter.
  Future<void> saveNextToken(int token);

  /// Clears only completed orders from active storage, keeping pending ones intact.
  Future<List<StallOrder>> clearCompletedOrders();

  /// Archives completed orders into historical archive storage.
  /// If [explicitOrders] is provided, archives those specific orders;
  /// otherwise archives orders completed longer ago than [threshold].
  Future<int> archiveCompletedOrders({
    Duration threshold = const Duration(hours: 24),
    List<StallOrder>? explicitOrders,
  });

  /// Loads archived historical orders.
  Future<List<StallOrder>> loadArchivedOrders();

  /// Clears all order history and optionally resets the token sequence.
  Future<void> clearAllOrders({bool resetToken = false});

  /// Loads category configurations and additional costs.
  Future<List<ItemCategory>> loadCategories() async => const [];

  /// Persists category configurations.
  Future<void> saveCategories(List<ItemCategory> categories) async {}
}
