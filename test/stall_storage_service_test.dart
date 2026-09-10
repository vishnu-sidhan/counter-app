import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/data/models/stall_models.dart';
import 'package:counter_app/data/services/stall_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('StallStorageService saves and loads menu items with category', () async {
    final service = StallStorageService();

    final items = [
      const MenuItem(id: '101', name: 'Masala Dosa', price: 80, category: 'South Indian'),
      const MenuItem(id: '102', name: 'Cold Coffee', price: 60, category: 'Beverages'),
    ];

    await service.saveMenu(items);
    final loaded = await service.loadMenu();

    expect(loaded.length, 2);
    expect(loaded[0].name, 'Masala Dosa');
    expect(loaded[0].category, 'South Indian');
    expect(loaded[1].name, 'Cold Coffee');
    expect(loaded[1].category, 'Beverages');
  });

  test('StallStorageService manages orders, completion, and clearing completed orders', () async {
    final service = StallStorageService();

    final order1 = StallOrder(
      token: 1,
      itemsSummary: '1x Chai',
      total: 20,
      timestamp: DateTime(2026, 9, 5, 10, 0),
      isCompleted: true,
      completedAt: DateTime(2026, 9, 5, 10, 5),
    );

    final order2 = StallOrder(
      token: 2,
      itemsSummary: '2x Samosa',
      total: 40,
      timestamp: DateTime(2026, 9, 5, 10, 10),
      isCompleted: false,
    );

    await service.saveOrders([order1, order2]);

    var orders = await service.loadOrders();
    expect(orders.length, 2);
    expect(orders[0].token, 1);
    expect(orders[0].isCompleted, isTrue);
    expect(orders[0].completedAt, isNotNull);
    expect(orders[1].token, 2);
    expect(orders[1].isCompleted, isFalse);

    // Clear completed orders
    final remaining = await service.clearCompletedOrders();
    expect(remaining.length, 1);
    expect(remaining[0].token, 2);
    expect(remaining[0].isCompleted, isFalse);

    // Verify persisted remaining orders
    orders = await service.loadOrders();
    expect(orders.length, 1);
    expect(orders[0].token, 2);
  });
}
