import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_app/controllers/order_controller.dart';
import 'package:counter_app/data/services/stall_storage_service.dart';

void main() {
  late StallStorageService storageService;
  late OrderController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'stall_menu': jsonEncode([
        {'id': 'item_1', 'name': 'Masala Chai', 'price': 20.0, 'category': 'Beverages'},
        {'id': 'item_2', 'name': 'Veg Samosa', 'price': 25.0, 'category': 'Snacks'},
        {'id': 'item_3', 'name': 'Cold Coffee', 'price': 50.0, 'category': 'Beverages'},
      ]),
      'stall_next_token': 101,
    });
    storageService = StallStorageService();
    controller = OrderController(storageService: storageService);
    await controller.loadPersistedData();
  });

  group('OrderController - Basic Operations', () {
    test('initializes with loaded menu and default state', () {
      expect(controller.menu.length, 3);
      expect(controller.nextToken, 101);
      expect(controller.cart, isEmpty);
      expect(controller.orders, isEmpty);
      expect(controller.activeOrders, isEmpty);
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
    });

    test('adds and removes items to/from cart', () {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      expect(controller.cart['item_1'], 1);
      expect(controller.cartItemCount, 1);
      expect(controller.cartTotal, 20.0);

      controller.addToCart(chai);
      expect(controller.cart['item_1'], 2);
      expect(controller.cartItemCount, 2);
      expect(controller.cartTotal, 40.0);

      controller.removeFromCart('item_1');
      expect(controller.cart['item_1'], 1);
      expect(controller.cartTotal, 20.0);

      controller.removeFromCart('item_1');
      expect(controller.cart.containsKey('item_1'), isFalse);
      expect(controller.cartTotal, 0.0);
    });
  });

  group('OrderController - Requirement 2: Optional Customer Name', () {
    test('places order without customer name successfully and falls back to Walk-in Customer', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);

      final outcome = await controller.punchOrUpdateOrder(
        customerName: null,
        paymentMethod: 'Cash',
      );

      expect(outcome.isEdit, isFalse);
      expect(outcome.token, 101);
      expect(controller.orders.length, 1);

      final order = controller.orders.first;
      expect(order.token, 101);
      expect(order.customerName, isNull);
      expect(order.displayCustomerName, 'Walk-in Customer');
      expect(order.isPaid, isFalse); // Default is payment pending

      // Confirm payment
      await controller.confirmPayment(token: 101, paymentMethod: 'Cash');
      expect(controller.orders.first.isPaid, isTrue);
      expect(controller.orders.first.paymentMethod, 'Cash');
      expect(controller.nextToken, 102);
      expect(controller.cart, isEmpty);
    });

    test('places order with custom customer name', () async {
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');
      controller.addToCart(samosa);

      await controller.punchOrUpdateOrder(
        customerName: 'Aarav Patel',
        paymentMethod: 'UPI',
      );

      final order = controller.orders.first;
      expect(order.customerName, 'Aarav Patel');
      expect(order.displayCustomerName, 'Aarav Patel');
      expect(order.paymentMethod, 'UPI');
    });
  });

  group('OrderController - Requirement 1: Order Editing & Deletion', () {
    test('edits an active order in-place without generating a new ID', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      // Place initial order
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Rahul',
        paymentMethod: 'Cash',
      );

      final originalOrder = controller.orders.first;
      expect(originalOrder.token, 101);
      expect(originalOrder.itemsSummary, '2x Masala Chai');
      expect(originalOrder.total, 40.0);
      expect(controller.nextToken, 102);

      // Start editing
      final custName = controller.startEditingOrder(originalOrder);
      expect(custName, 'Rahul');
      expect(controller.isEditing, isTrue);
      expect(controller.editingOrderId, 101);
      expect(controller.cart['item_1'], 2);

      // Modify items in cart: add a Samosa
      controller.addToCart(samosa);
      expect(controller.cartTotal, 65.0); // 40 + 25

      // Save / Update order
      final updateOutcome = await controller.punchOrUpdateOrder(
        customerName: 'Rahul M',
        paymentMethod: 'UPI',
      );

      expect(updateOutcome.isEdit, isTrue);
      expect(updateOutcome.token, 101);
      expect(controller.nextToken, 102); // Token should NOT have incremented
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);

      // Verify order record updated in-place
      expect(controller.orders.length, 1);
      final updated = controller.orders.first;
      expect(updated.token, 101);
      expect(updated.total, 65.0);
      expect(updated.customerName, 'Rahul M');
      expect(updated.paymentMethod, 'UPI');
      expect(updated.items['item_1'], 2);
      expect(updated.items['item_2'], 1);
    });

    test('edge case: editing an order with removed items', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');

      // Order with 2 chai and 2 samosas
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(
        customerName: 'Priya',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);

      // Remove both samosas from cart
      controller.removeFromCart('item_2');
      controller.removeFromCart('item_2');
      expect(controller.cart.containsKey('item_2'), isFalse);
      expect(controller.cart['item_1'], 2);

      await controller.punchOrUpdateOrder(
        customerName: 'Priya',
        paymentMethod: 'Cash',
      );

      final updated = controller.orders.first;
      expect(updated.items.containsKey('item_2'), isFalse);
      expect(updated.items['item_1'], 2);
      expect(updated.total, 40.0);
    });

    test('edge case: deleting the currently edited order cancels edit mode', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Sam',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);
      expect(controller.isEditing, isTrue);

      // Delete the order while editing it
      await controller.deleteOrder(order.token);

      expect(controller.orders, isEmpty);
      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);
    });

    test('cancelEditingOrder restores cart to clean state without modifying order', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(
        customerName: 'Neha',
        paymentMethod: 'Cash',
      );

      final order = controller.orders.first;
      controller.startEditingOrder(order);
      controller.addToCart(chai); // cart is now 2x

      controller.cancelEditingOrder();

      expect(controller.isEditing, isFalse);
      expect(controller.editingOrderId, isNull);
      expect(controller.cart, isEmpty);
      // Original order intact with 1x
      expect(controller.orders.first.total, 20.0);
    });
  });

  group('OrderController - Requirement 5: Combined Orders View (Consolidated Items)', () {
    test('combinedActiveOrders aggregates quantities and orders tags across multiple tickets for confirmed payment orders only', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');
      final samosa = controller.menu.firstWhere((m) => m.id == 'item_2');
      final coffee = controller.menu.firstWhere((m) => m.id == 'item_3');

      // Order #101: 3x Chai, 2x Samosa (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(samosa);
      await controller.punchOrUpdateOrder(customerName: 'Table 1', paymentMethod: 'Cash', isPaid: true);

      // Order #102: 2x Chai, 1x Samosa, 4x Coffee (Unpaid initially)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(samosa);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      controller.addToCart(coffee);
      await controller.punchOrUpdateOrder(customerName: 'Table 2', paymentMethod: 'UPI', isPaid: false);

      // Before confirming #102, combinedActiveOrders only has items from #101
      expect(controller.combinedActiveOrders.length, 2);
      expect(controller.combinedActiveOrders.firstWhere((a) => a.itemName == 'Masala Chai').totalQuantity, 3);

      // Confirm payment for #102
      await controller.confirmPayment(token: 102, paymentMethod: 'UPI');

      // Order #103: 3x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'Table 3', paymentMethod: 'Cash', isPaid: true);

      final aggregated = controller.combinedActiveOrders;
      expect(aggregated.length, 3);

      // Check Masala Chai: 3 + 2 + 3 = 8
      final chaiSummary = aggregated.firstWhere((a) => a.itemName == 'Masala Chai');
      expect(chaiSummary.totalQuantity, 8);
      expect(chaiSummary.category, 'Beverages');
      expect(chaiSummary.tickets.length, 3);
      expect(chaiSummary.tickets[0].token, 101);
      expect(chaiSummary.tickets[0].quantity, 3);
      expect(chaiSummary.tickets[1].token, 102);
      expect(chaiSummary.tickets[1].quantity, 2);
      expect(chaiSummary.tickets[2].token, 103);
      expect(chaiSummary.tickets[2].quantity, 3);

      // Check Cold Coffee: 4
      final coffeeSummary = aggregated.firstWhere((a) => a.itemName == 'Cold Coffee');
      expect(coffeeSummary.totalQuantity, 4);
      expect(coffeeSummary.tickets.length, 1);
      expect(coffeeSummary.tickets[0].token, 102);
      expect(coffeeSummary.tickets[0].quantity, 4);

      // Check Veg Samosa: 2 + 1 = 3
      final samosaSummary = aggregated.firstWhere((a) => a.itemName == 'Veg Samosa');
      expect(samosaSummary.totalQuantity, 3);
      expect(samosaSummary.tickets.length, 2);
    });

    test('combinedActiveOrders updates reactively when orders are completed or deleted', () async {
      final chai = controller.menu.firstWhere((m) => m.id == 'item_1');

      // Order 101: 2x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'A', paymentMethod: 'Cash', isPaid: true);

      // Order 102: 3x Chai (Paid)
      controller.addToCart(chai);
      controller.addToCart(chai);
      controller.addToCart(chai);
      await controller.punchOrUpdateOrder(customerName: 'B', paymentMethod: 'UPI', isPaid: true);

      expect(controller.combinedActiveOrders.first.totalQuantity, 5);

      // Complete Order 101
      await controller.completeOrder(101);
      expect(controller.combinedActiveOrders.first.totalQuantity, 3);
      expect(controller.combinedActiveOrders.first.tickets.length, 1);
      expect(controller.combinedActiveOrders.first.tickets.first.token, 102);

      // Delete Order 102
      await controller.deleteOrder(102);
      expect(controller.combinedActiveOrders, isEmpty);
    });
  });
}
